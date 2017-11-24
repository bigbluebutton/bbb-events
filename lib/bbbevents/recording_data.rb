require 'nokogiri'
require 'nori'

module BBBEvents
  class RecordingData
    attr_reader :metadata, :meeting_id, :attendees, :files, :chat, :emojis
      
    def initialize(file)
      parser = Nori.new
      recording = parser.parse(File.read(file))['recording']
      
      @metadata = recording['metadata']
      @meeting_id = recording['meeting']['@id']
      
      @time_offset = recording['event'][0]['@timestamp'].to_i + @meeting_id.split('-')[1].to_i
      
      @attendees = []
      @files = []
      @chat = []
      @emojis = {}

      process_events(recording['event'])
    end
      
    def viewers
      @attendees.select do |att| !att[:moderator] end
    end
      
    def moderators
      @attendees.select do |att| att[:moderator] end
    end
      
    private
    
    def convert_time(timestamp)
      Time.at(((timestamp.to_i - @time_offset) * -1) / 1000).strftime("%m/%d/%Y %H:%M:%S")
    end
    
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
          join: convert_time(e['@timestamp']),
          chats: 0,
          talks: 0,
          emojis: 0
        }
      end
    end
    
    def ParticipantLeftEvent(e)
      att = find_attendee(e['userId'])
      att[:left] = convert_time(e['@timestamp']) if att
    end
    
    def SharePresentationEvent(e)
      @files << e['originalFilename']
    end

    def PublicChatEvent(e)
      @chat << {
        sender: e['sender'],
        senderId: e['senderId'],
        message: e['message'],
        timestamp: convert_time(e['@timestamp'])
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
  
  end
end
