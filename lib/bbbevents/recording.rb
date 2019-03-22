require 'csv'
require 'json'
require 'active_support/core_ext/hash'

module BBBEvents
  CSV_HEADER = %w(id extUserId name moderator chats talks emojis poll_votes raisehand talk_time join left duration)
  NO_VOTE_SYMBOL = "-"

  class Recording
    include Events

    attr_accessor :metadata, :meeting_id, :timestamp, :start, :finish, :duration, :files

    def initialize(events_xml)
      filename = File.basename(events_xml)
      raise "#{filename} is not a file or does not exist." unless File.file?(events_xml)

      raw_recording_data = Hash.from_xml(File.read(events_xml))

      raise "#{filename} is not a valid xml file (unable to parse)." if raw_recording_data.nil?
      raise "#{filename} is missing recording key." unless raw_recording_data.key?("recording")

      recording_data = raw_recording_data["recording"]
      events         = recording_data["event"]

      @metadata   = recording_data["metadata"]
      @meeting_id = recording_data["meeting"]["id"]
      @timestamp  = extract_timestamp(@meeting_id)

      @first_event = events.first["timestamp"].to_i
      @last_event  = events.last["timestamp"].to_i

      @start    = Time.at(@timestamp / 1000)
      @finish   = Time.at(timestamp_conversion(@last_event))
      @duration = (@finish - @start).to_i

      @attendees = {}
      @polls     = {}
      @files     = []

      process_events(events)

      @attendees.values.each do |att|
        att.leaves << @finish if att.joins.length > att.leaves.length
        att.duration = total_duration(att)
      end
    end

    # Take only the values since we no longer need to index.
    def attendees
      @attendees.values
    end

    # Retrieve a list of all the moderators.
    def moderators
      attendees.select(&:moderator?)
    end

    # Retrieve a list of all the viewers.
    def viewers
      attendees.reject(&:moderator?)
    end

    # Take only the values since we no longer need to index.
    def polls
      @polls.values
    end

    # Retrieve a list of published polls.
    def published_polls
      polls.select(&:published?)
    end

    # Retrieve a list of unpublished polls.
    def unpublished_polls
      polls.reject(&:published?)
    end

    # Export recording data to a CSV file.
    def create_csv(filepath)
      CSV.open(filepath, "wb") do |csv|
        csv << CSV_HEADER.map(&:capitalize) + (1..polls.length).map { |i| "Poll #{i}" }
        @attendees.each do |id, att|
          csv << att.csv_row + polls.map { |poll| poll.votes[id] || NO_VOTE_SYMBOL }
        end
      end
    end

    def attendees_to_array
      att_array = Array.new
      @attendees.values.map { |att| 
        att_array.push(att.to_hash)
      }
      att_array
    end

    def polls_to_array
      polls_array = Array.new
      @polls.values.map { |poll| 
        polls_array.push(poll.to_hash)
      }
      polls_array
    end

    def to_json
      att_array = attendees_to_array
      polls_array = polls_to_array
      {
        metadata: @metadata,
        meeting_id: @meeting_id,
        duration: @duration,
        start: @start,
        finish: @finish,
        attendees: att_array, 
        files: @files,
        polls: polls_array,
      }.to_json
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
      (base.to_i - @first_event + @timestamp) / 1000
    end

    # Calculates an attendee's duration.
    def total_duration(att)
      return 0 unless att.joins.length == att.leaves.length
      total = 0

      att.joins.length.times do |i|
        total += att.leaves[i] - att.joins[i]
      end
      total
    end
  end
end
