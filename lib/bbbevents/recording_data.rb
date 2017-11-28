require 'json'

require 'nokogiri'
require 'nori'

module BBBEvents
  class RecordingData
    attr_reader :metadata, :meeting_id, :attendees, :files, :chat, :emojis, :polls
      
    def initialize(file)
      parser = Nori.new
      recording = parser.parse(File.read(file))['recording']
      
      @metadata = recording['metadata']
      @meeting_id = recording['meeting']['@id']
      
      @first_event = recording['event'][0]['@timestamp'].to_i
      @meeting_timestamp = @meeting_id.split('-')[1].to_i
      
      @attendees, @files, @chat, @polls = [], [], [], []
      @emojis = {}

      process_events(recording['event'])
      
      @attendees.each do |att|
        att[:join] = Time.at(att[:join]).strftime("%m/%d/%Y %H:%M:%S")
        att[:left] = Time.at(att[:left]).strftime("%m/%d/%Y %H:%M:%S")
      end
    end
      
    def viewers
      @attendees.select do |att| !att[:moderator] end
    end
      
    def moderators
      @attendees.select do |att| att[:moderator] end
    end
      
    private
    
    def find_attendee(user_id)
      @attendees.each do |att|
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
        @attendees << {
          name: e['name'],
          user_id: e['userId'],
          moderator: e['role'] == 'MODERATOR',
          join: (e['@timestamp'].to_i - @first_event + @meeting_timestamp) / 1000,
          chats: 0,
          talks: 0,
          emojis: 0
        }
      end
    end
    
    def ParticipantLeftEvent(e)
      att = find_attendee(e['userId'])
      if att
        att[:left] = (e['@timestamp'].to_i - @first_event + @meeting_timestamp) / 1000
        att[:duration] = Time.at(att[:left] - att[:join]).utc.strftime("%H:%M:%S")
      end
    end
    
    def SharePresentationEvent(e)
      @files << e['originalFilename']
    end

    def PublicChatEvent(e)
      @chat << {
        sender: e['sender'],
        senderId: e['senderId'],
        message: e['message'],
        timestamp: convert_time((e['@timestamp'].to_i - @first_event + @meeting_timestamp) / 1000)
      }
      att = find_attendee(e['senderId'])
      att[:chats] += 1 if att
    end
    
    def ParticipantTalkingEvent(e)
      if e['talking']
        att = find_attendee(e['participant'])
        att[:talks] += 1 if att
      end
    end
    
    def ParticipantStatusChangeEvent(e)
      att = find_attendee(e['userId'])
      att[:emojis] += 1 if att
      @emojis[e['value']] = 0 if @emojis[e['value']].nil?
      @emojis[e['value']] += 1
    end
  
    def AddShapeEvent(e)
      if e['type'] == 'poll_result'
        @polls << {
          initiator: e['userId'],
          num_responders: e['num_responders'],
          options: JSON.parse(e['result'])
        }
      end
    end
  
  end
end
