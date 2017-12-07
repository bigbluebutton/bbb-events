require 'json'
require 'nokogiri'
require 'nori'

module BBBEvents
  class RecordingData
    attr_reader :data
      
    def initialize(file)
      parser = Nori.new
      recording = parser.parse(File.read(file))['recording']
      
      @data = {
        metadata: recording['metadata'],
        meeting_id: recording['meeting']['@id'],
        attendees: {},
        files: [],
        chat: [],
        polls: {},
        emojis: {}
      }
      
      @first_event = recording['event'][0]['@timestamp'].to_i
      @last_event = recording['event'][-1]['@timestamp'].to_i
      @meeting_timestamp = @data[:meeting_id].split('-')[1].to_i

      process_events(recording['event'])
      
      # Convert times.
      @data[:attendees].each do |uid, att|
        # Sometimes the left events are missing, use last event if that's the case.
        att[:left] = @last_event unless att[:left]
        att[:duration] = Time.at(att[:left] - att[:join]).utc.strftime("%H:%M:%S")
        att[:talk_time] = Time.at(att[:talk_time]).utc.strftime("%H:%M:%S")
        att[:join] = Time.at(att[:join]).strftime("%m/%d/%Y %H:%M:%S")
        att[:left] = Time.at(att[:left]).strftime("%m/%d/%Y %H:%M:%S")
        # Remove unneeded key.
        att.delete(:last_talking_time)
      end
      
      # Set meeting duration.
      @data[:duration] = convert_time((@last_event - @first_event) / 1000)
    end
      
    # Make simple getters directly on the RecordingData object for specifics.
    %w(metadata meeting_id attendees files chat polls emojis duration).map(&:to_sym).each do |k|
      define_method(k) do @data[k] end
    end
      
    def viewers
      @data[:attendees].select do |uid, att| !att[:moderator] end
    end
      
    def moderators
      @data[:attendees].select do |uid, att| att[:moderator] end
    end
      
    private
    
    def convert_time(t)
      Time.at(t).utc.strftime("%H:%M:%S")
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
      unless @data[:attendees].key?(e['userId'])
        @data[:attendees][e['userId']] = {
          name: e['name'],
          moderator: e['role'] == 'MODERATOR',
          join: (e['@timestamp'].to_i - @first_event + @meeting_timestamp) / 1000,
          chats: 0,
          talks: 0,
          emojis: 0,
          poll_votes: 0,
          raisehand: 0,
          last_talking_time: nil,
          talk_time: 0
        }
      end
    end
    
    def ParticipantLeftEvent(e)
      # If the attendee exists, set their leave time.
      if att = @data[:attendees][e['userId']]
        att[:left] = (e['@timestamp'].to_i - @first_event + @meeting_timestamp) / 1000
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
        senderId: e['senderId'],
        message: e['message'],
        timestamp: convert_time((e['@timestamp'].to_i - @first_event + @meeting_timestamp) / 1000)
      }
      
      # If the attendee exists, increment their messages.
      if att = @data[:attendees][e['senderId']]
        att[:chats] += 1
      end
    end
    
    def ParticipantTalkingEvent(e)
      if att = @data[:attendees][e['participant']]
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
      if att = @data[:attendees][e['userId']]
        emoji == 'raiseHand' ? att[:raisehand] += 1 : att[:emojis] += 1
      end
      
      # Add to the total emoji list.
      @data[:emojis][emoji] ? @data[:emojis][emoji] += 1 : @data[:emojis][emoji] = 1
    end
  
    def PollStartedRecordEvent(e)
      poll_id = e['pollId']
      start = Time.at((e['@timestamp'].to_i - @first_event + @meeting_timestamp) / 1000).utc.strftime("%H:%M:%S")
      
      # Create the poll.
      @data[:polls][poll_id] = {
        metadata: {
          start: start,
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
      user_id = e['userId']
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

  end
end
