require 'json'
require 'nokogiri'
require 'nori'
require 'csv'

module BBBEvents
  class RecordingData
    attr_reader :data
      
    def initialize(file)
      parser = Nori.new
      recording = parser.parse(File.read(file))['recording']
      
      @first_event = recording['event'][0]['@timestamp'].to_i
      @last_event = recording['event'][-1]['@timestamp'].to_i
      @meeting_timestamp = recording['meeting']['@id'].split('-')[1].to_i
      
      @data = {
        metadata: recording['metadata'],
        meeting_id: recording['meeting']['@id'],
        duration: convert_time((@last_event - @first_event) / 1000),
        start: convert_date(@meeting_timestamp / 1000),
        finish: convert_date((@last_event - @first_event + @meeting_timestamp) / 1000),
        attendees: {},
        files: [],
        chat: [],
        polls: {},
        emojis: {}
      }

      # Map to look up external user id (for @data[:attendees]) from the
      # internal user id in most recording events
      @externalUserId = {}

      process_events(recording['event'])
      
      # Convert times.
      @data[:attendees].each do |uid, att|
        # Sometimes the left events are missing, use last event if that's the case.
        if !att[:left]
          att[:left] = ((@last_event - @first_event + @meeting_timestamp) / 1000)
          att[:duration] = att[:duration] + (att[:left] - att[:last_join])
        emd
        att[:talk_time] = convert_time(att[:talk_time])
        att[:join] = convert_date(att[:join])
        att[:left] = convert_date(att[:left])
        # Remove unneeded keys.
        att.delete(:last_talking_time)
        att.delete(:last_join)
      end
    end
    
    def create_csv(filepath)
      CSV.open(filepath, "wb") do |csv|
        # Create header row with polls.
        csv << @data[:attendees].values.first.keys.map(&:capitalize) + (1..@data[:polls].length).map do |i| "Poll #{i}" end
        @data[:attendees].each do |uid, att|
          # Create a row for each attendee and add their poll answers.
          csv << att.values + @data[:polls].values.map do |poll| poll[:votes][uid] || '-' end
        end
      end
    end
      
    # Make simple getters directly on the RecordingData object for specifics.
    %w(metadata meeting_id duration start finish attendees files chat polls emojis).map(&:to_sym).each do |k|
      define_method(k) do @data[k] end
    end
      
    def viewers
      @data[:attendees].select do |uid, att| !att[:moderator] end
    end
      
    def moderators
      @data[:attendees].select do |uid, att| att[:moderator] end
    end
    
    def published_polls
      @data[:polls].select do |id, poll| poll[:metadata][:published] end
    end
      
    def unpublished_polls
      @data[:polls].select do |id, poll| !poll[:metadata][:published] end
    end
      
    private
    
    def convert_time(t)
      Time.at(t).utc.strftime("%H:%M:%S")
    end
    
    def convert_date(t)
      Time.at(t).strftime("%m/%d/%Y %H:%M:%S")
    end
    
    def process_events(events)
      events.each do |e|
        begin
          send(e['@eventname'], e)
        rescue
        end
      end
    end
  
    def ParticipantJoinEvent(e)
      # If they don't exist, initialize the user.
      unless @externalUserId.key?(e['userId'])
        @externalUserId[e['userId']] = e['externalUserId']
      end
      unless @data[:attendees].key?(e['externalUserId'])
        @data[:attendees][e['externalUserId']] = {
          name: e['name'],
          moderator: e['role'] == 'MODERATOR',
          chats: 0,
          talks: 0,
          emojis: 0,
          poll_votes: 0,
          raisehand: 0,
          last_talking_time: nil,
          talk_time: 0,
          join: (e['@timestamp'].to_i - @first_event + @meeting_timestamp) / 1000,
          duration: 0
        }
      end

      # Handle updates for re-joining users
      att = @data[:attendees][e['externalUserId']]
      att[:name] = e['name']
      att[:last_join] = (e['@timestamp'].to_i - @first_event + @meeting_timestamp) / 1000
      att.delete(:left)
      if e['role'] == 'MODERATOR'
        att[:moderator] = true
      end
    end
    
    def ParticipantLeftEvent(e)
      # If the attendee exists, set their leave time.
      if att = @data[:attendees][@externalUserId[e['userId']]]
        att[:left] = (e['@timestamp'].to_i - @first_event + @meeting_timestamp) / 1000
        att[:duration] = att[:duration] + (att[:left] - att[:last_join])
      end
    end
    
    def ConversionCompletedEvent(e)
      # Add the uploaded file to the list of files.
      @data[:files] << e['originalFilename']
    end

    def PublicChatEvent(e)
      # Add the chat event to the chat list.
      @data[:chat] << {
        sender: e['sender'],
        senderId: @externalUserId[e['senderId']],
        message: e['message'],
        timestamp: convert_time((e['@timestamp'].to_i - @first_event + @meeting_timestamp) / 1000)
      }
      
      # If the attendee exists, increment their messages.
      if att = @data[:attendees][@externalUserId[e['senderId']]]
        att[:chats] += 1
      end
    end
    
    def ParticipantTalkingEvent(e)
      if att = @data[:attendees][@externalUserId[e['participant']]]
        # Track talk time between events and record number of times talking.
        if e['talking']
          att[:last_talking_time] = (e['@timestamp'].to_i - @first_event + @meeting_timestamp) / 1000
          att[:talks] += 1
        else
          att[:talk_time] += ((e['@timestamp'].to_i - @first_event + @meeting_timestamp) / 1000) - att[:last_talking_time]
        end
      end
    end
    
    def ParticipantStatusChangeEvent(e)
      # Track the emoji for the user (differentiate between raise hand).
      emoji = e['value']
      if att = @data[:attendees][@externalUserId[e['userId']]]
        emoji == 'raiseHand' ? att[:raisehand] += 1 : att[:emojis] += 1
      end
      
      # Add to the total emoji list.
      @data[:emojis][emoji] ? @data[:emojis][emoji] += 1 : @data[:emojis][emoji] = 1
    end
  
    def PollStartedRecordEvent(e)
      poll_id = e['pollId']
      start = convert_time((e['@timestamp'].to_i - @first_event + @meeting_timestamp) / 1000)
      
      # Create the poll.
      @data[:polls][poll_id] = {
        metadata: {
          start: start,
          published: false,
          options: []
        },
        votes: {}
      }
      
      # Populate the options.
      JSON.parse(e['answers']).each do |opt|
        @data[:polls][poll_id][:metadata][:options] << opt['key']
      end
    end

    def UserRespondedToPollRecordEvent(e)
      poll_id = e['pollId']
      user_id = @externalUserId[e['userId']]
      answer = e['answerId'].to_i
      
      # Record the answer in the poll.
      if poll = @data[:polls][poll_id]
        poll[:votes][user_id] = poll[:metadata][:options][answer]
      end
      
      # Increment the users poll votes.
      if att = @data[:attendees][user_id]
        att[:poll_votes] += 1
      end
    end
    
    def AddShapeEvent(e)
      # If we are drawing poll results on the slide.
      if e['type'] == 'poll_result'
        if poll = @data[:polls][e['id']]
          # Set the poll as published.
          poll[:metadata][:published] = true
        end
      end
    end

  end
end
