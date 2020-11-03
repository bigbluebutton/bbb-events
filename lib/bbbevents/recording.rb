require 'csv'
require 'json'
require 'active_support/core_ext/hash'
require 'time'

module BBBEvents
  CSV_HEADER = %w(name moderator chats talks emojis poll_votes raisehand talk_time join left duration)
  NO_VOTE_SYMBOL = "-"

  class Recording
    include Events

    attr_accessor :metadata, :meeting_id, :timestamp, :start, :finish, :duration, :files

    def initialize(events_xml)
      filename = File.basename(events_xml)
      raise "#{filename} is not a file or does not exist." unless File.file?(events_xml)

      # The Hash.from_xml automatically converts keys with dashes '-' to snake_case
      # (i.e canvas-recording-ready-url becomes canvas_recording_ready_url)
      # see https://www.rubydoc.info/github/datamapper/extlib/Hash.from_xml
      raw_recording_data = Hash.from_xml(File.read(events_xml))

      raise "#{filename} is not a valid xml file (unable to parse)." if raw_recording_data.nil?
      raise "#{filename} is missing recording key." unless raw_recording_data.key?("recording")

      recording_data = raw_recording_data["recording"]
      events = recording_data["event"]
      events = [] if events.nil?
      events = [events] unless events.is_a?(Array)

      @metadata   = recording_data["metadata"]
      @meeting_id = recording_data["metadata"]["meetingId"]

      internal_meeting_id = recording_data["meeting"]["id"]

      @timestamp  = extract_timestamp(internal_meeting_id)
      @start = Time.at(@timestamp / 1000)

      if events.length > 0
        @first_event = events.first["timestamp"].to_i
        @last_event  = events.last["timestamp"].to_i
        @finish = Time.at(timestamp_conversion(@last_event))
      else
        @finish = @start
      end
      @duration = (@finish - @start).to_i

      @attendees = {}
      @polls     = {}
      @files     = []

      # Map to look up external user id (for @data[:attendees]) from the
      # internal user id in most recording events
      @externalUserId = {}

      process_events(events)

      @attendees.values.each do |att|
        att.leaves << @finish if att.joins.length > att.leaves.length
        att.duration = total_duration(att)
        att.duration_human = Time.at(att.duration).utc.strftime("%H:%M:%S")
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

    def to_h
      # Transform any CamelCase keys to snake_case.
      @metadata.deep_transform_keys! do |key|
          k = key.to_s.underscore rescue key
          k.to_sym rescue key
        end

      {
        metadata: @metadata,
        meeting_id: @meeting_id,
        duration: @duration,
        start: @start,
        finish: @finish,
        attendees: attendees.map(&:to_h),
        files: @files,
        polls: polls.map(&:to_h)
      }
    end

    def to_json
      to_h.to_json
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
      joins_leaves_arr = []
      att.joins.each { |j| joins_leaves_arr.append({:time => j.to_i, :datetime => j, :event => :join})}
      att.leaves.each { |j| joins_leaves_arr.append({:time => j.to_i, :datetime => j, :event => :left})}

      #puts "BEGIN ============"
      #puts "user: #{att.name} #{att.id} #{att.ext_user_id}"
      #puts " Events: "

      joins_leaves_arr_sorted = joins_leaves_arr.sort_by { |event| event[:time] }

      #puts joins_leaves_arr_sorted
      #puts "\n Calculating duration: "

      partial_duration = 0
      prev_event = nil

      joins_leaves_arr_sorted.each do |cur_event|
        duration = 0
        if prev_event != nil and cur_event[:event] == :join and prev_event[:event] == :left
          # user left and rejoining, don't update duration
          prev_event = cur_event
        elsif prev_event != nil
          duration = cur_event[:time] - prev_event[:time]
          partial_duration += duration
          prev_event = cur_event
        else
          prev_event = cur_event
        end

        #puts "#{cur_event[:datetime]} cur_duration=#{Time.at(duration).utc.strftime("%H:%M:%S")} duration=#{Time.at(partial_duration).utc.strftime("%H:%M:%S")} join=#{cur_event[:event]} "
      end

      #puts "\n"
      #puts "------------"
      #puts "user duration = #{Time.at(partial_duration).utc.strftime("%H:%M:%S")}"
      #puts "============ END"
      #puts "\n"
      return partial_duration
    end
  end
end
