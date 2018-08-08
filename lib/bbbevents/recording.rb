require 'csv'
require 'json'
require 'active_support/core_ext/hash'

module BBBEvents

  CSV_HEADER = %w(name moderator chats talks emojis poll_votes raisehand talk_time join left duration)
  NO_VOTE_SYMBOL = "-"

  class Recording
    include Events

    attr_accessor :metadata, :meeting_id, :attendees, :polls, :files

    def initialize(events_xml)
      raise "#{events_xml} is not a file or does not exist." unless File.file?(events_xml)

      raw_recording_data = Hash.from_xml(File.read(events_xml))

      raise "#{events_xml} is missing recording key." unless raw_recording_data.key?("recording")

      recording_data = raw_recording_data["recording"]
      events         = recording_data["event"]

      @metadata   = recording_data["metadata"]
      @meeting_id = recording_data["meeting"]["id"]
      @timestamp  = extract_timestamp(@meeting_id)

      @first_event = events.first["timestamp"].to_i
      @last_event  = events.last["timestamp"].to_i

      @start    = Time.at(@timestamp / 1000).strftime(DATE_FORMAT)
      @finish   = Time.at(timestamp_conversion(@last_event)).strftime(DATE_FORMAT)
      @duration = Time.at((@last_event - @first_event) / 1000).utc.strftime(TIME_FORMAT)

      @attendees = {}
      @polls     = {}
      @files     = []

      process_events(events)
    end

    # Retrieve a list of all the moderators.
    def moderators
      @attendees.select { |id, att| att.moderator? }
    end

    # Retrieve a list of all the viewers.
    def viewers
      @attendees.reject { |id, att| att.moderator? }
    end

    # Retrieve a list of published polls.
    def published_polls
      @polls.select { |id, poll| poll.dig(:metadata, :published) }
    end

    # Retrieve a list of unpublished polls.
    def unpublished_polls
      @polls.select { |id, poll| !poll.dig(:metadata, :published) }
    end

    # Export recording data to a CSV file.
    def create_csv(filepath)
      CSV.open(filepath, "wb") do |csv|
        csv << CSV_HEADER.map(&:capitalize) + (1..@polls.length).map { |i| "Poll #{i}" }
        @attendees.each do |id, att|
          csv << att.csv_row + @polls.values.map { |poll| poll[:votes][id] || NO_VOTE_SYMBOL }
        end
      end
    end

    private

    # Process all the events in the events.xml file.
    def process_events(events)
      events.each do |e|
        event = e["eventname"].underscore
        send(event, e) if RECORDABLE_EVENTS.include?(event)
      end
    end

    # Extracts the timestamp from a meeting id.
    def extract_timestamp(meeting_id)
      meeting_id.split("-").last.to_i
    end

    # Converts the BigBlueButton timestamps to proper time.
    def timestamp_conversion(base)
      (base.to_i + @first_event + @timestamp) / 1000
    end
  end
end
