require 'json'

require 'nokogiri'
require 'nori'

module BBBEvents
  class RecordingData
    attr_reader :data
      
    def initialize(file)
      parser = Nori.new
      recording = parser.parse(File.read(file))['recording']
      
      @data = {}
      @data[:metadata] = recording['metadata']
      @data[:meeting_id] = recording['meeting']['@id']
      @data[:attendees] = []
      @data[:files] = []
      @data[:chat] = []
      @data[:polls] = []
      @data[:emojis] = {}
      
      @first_event = recording['event'][0]['@timestamp'].to_i
      @last_event = recording['event'][-1]['@timestamp'].to_i
      @meeting_timestamp = @data[:meeting_id].split('-')[1].to_i

      process_events(recording['event'])
      
      # Convert times.
      @data[:attendees].each do |att|
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
      @data[:attendees].select do |att| !att[:moderator] end
    end
      
    def moderators
      @data[:attendees].select do |att| att[:moderator] end
    end
      
    private
    
    def convert_time(t)
      Time.at(t).utc.strftime("%H:%M:%S")
    end
    
    def find_attendee(user_id)
      @data[:attendees].each do |att|
        return att if att[:user_id] == user_id
      end
      nil
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
      if find_attendee(e['userId']).nil?
        @data[:attendees] << {
          name: e['name'],
          user_id: e['userId'],
          moderator: e['role'] == 'MODERATOR',
          join: (e['@timestamp'].to_i - @first_event + @meeting_timestamp) / 1000,
          chats: 0,
          talks: 0,
          emojis: 0,
          raisehand: 0,
          last_talking_time: nil,
          talk_time: 0
        }
      end
    end
    
    def ParticipantLeftEvent(e)
      att = find_attendee(e['userId'])
      att[:left] = (e['@timestamp'].to_i - @first_event + @meeting_timestamp) / 1000 if att
    end
    
    def ConversionCompletedEvent(e)
      @data[:files] << e['originalFilename']
    end

    def PublicChatEvent(e)
      @data[:chat] << {
        sender: e['sender'],
        senderId: e['senderId'],
        message: e['message'],
        timestamp: convert_time((e['@timestamp'].to_i - @first_event + @meeting_timestamp) / 1000)
      }
      att = find_attendee(e['senderId'])
      att[:chats] += 1 if att
    end
    
    def ParticipantTalkingEvent(e)
      att = find_attendee(e['participant'])
      if att
        if e['talking']
          att[:last_talking_time] = (e['@timestamp'].to_i - @first_event + @meeting_timestamp) / 1000
          att[:talks] += 1
        else
          att[:talk_time] += ((e['@timestamp'].to_i - @first_event + @meeting_timestamp) / 1000) - att[:last_talking_time]
        end
      end
    end
    
    def ParticipantStatusChangeEvent(e)
      att = find_attendee(e['userId'])
      if att
        e['value'] == 'raiseHand' ? att[:raisehand] += 1 : att[:emojis] += 1
      end
      @data[:emojis][e['value']] = 0 if @data[:emojis][e['value']].nil?
      @data[:emojis][e['value']] += 1
    end
  
    def AddShapeEvent(e)
      if e['type'] == 'poll_result'
        @data[:polls] << {
          initiator: e['userId'],
          num_responders: e['num_responders'],
          options: JSON.parse(e['result'])
        }
      end
    end

  end
end
