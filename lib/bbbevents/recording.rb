require 'csv'
require 'json'
require 'active_support'
require 'active_support/core_ext/hash'


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
        att.duration = total_duration(@finish, att)
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

    # Transform any CamelCase keys to snake_case
    def transform_metadata
      @metadata.deep_transform_keys do |key|
        k = key.to_s.underscore rescue key
        k.to_sym rescue key
      end
    end

    def to_h
      {
        metadata: transform_metadata,
        meeting_id: @meeting_id,
        duration: @duration,
        start: @start,
        finish: @finish,
        attendees: attendees.map(&:to_h),
        files: @files,
        polls: polls.map(&:to_h)
      }
    end

    def as_json
      {
        metadata: transform_metadata,
        meeting_id: @meeting_id,
        duration: @duration,
        start: BBBEvents.format_datetime(@start),
        finish: BBBEvents.format_datetime(@finish),
        attendees: attendees.map(&:as_json),
        files: @files,
        polls: polls.map(&:as_json)
      }
    end

    def to_json
      JSON.generate(as_json)
    end

    def calculate_user_duration(join_events, left_events)
      joins_leaves_arr = []
      join_events.each { |j| joins_leaves_arr.append({:time => j.to_i, :datetime => j, :event => :join})}
      left_events.each { |j| joins_leaves_arr.append({:time => j.to_i, :datetime => j, :event => :left})}

      joins_leaves_arr_sorted = joins_leaves_arr.sort_by { |event| event[:time] }

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
      end

      return partial_duration
    end

    # Time the attendee was in the meeting, in seconds. An attendee has a session
    # per internal user id (e.g. two browser tabs, or a rejoin with a new id), and
    # time covered by more than one session is counted once.
    def calculate_user_duration_based_on_userid(last_event_ts, sessions)
      intervals = sessions.values.flat_map { |session| session_intervals(session, last_event_ts) }
      merge_intervals(intervals).sum { |start, stop| stop.to_i - start.to_i }
    end

    private

    # [start, stop] pairs of the time a session was in the meeting. A join while
    # already in (its left event went missing) keeps the session in, a left while
    # out is ignored, and a session still in at the end stays until last_event_ts.
    # A join and a left at the same instant alternate from the session's state: a
    # session that was in left and rejoined, one that was out joined and left.
    def session_intervals(session, last_event_ts)
      intervals = []
      start = nil

      events_by_time = (session[:joins] + session[:lefts]).group_by { |event| event[:timestamp] }
      events_by_time.sort_by(&:first).each do |timestamp, events|
        joins = events.count { |event| event[:event] == :join }
        lefts = events.length - joins
        in_meeting = joins > lefts || (joins == lefts && !start.nil?)

        if in_meeting && start.nil?
          start = timestamp
        elsif !in_meeting && !start.nil?
          intervals << [start, timestamp]
          start = nil
        end
      end

      intervals << [start, last_event_ts] unless start.nil?
      intervals
    end

    # Merges overlapping and touching intervals.
    def merge_intervals(intervals)
      merged = []
      intervals.sort_by(&:first).each do |start, stop|
        if merged.any? && start <= merged.last[1]
          merged.last[1] = [merged.last[1], stop].max
        else
          merged << [start, stop]
        end
      end
      merged
    end

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
    def total_duration(last_event_ts, att)
      calculate_user_duration_based_on_userid(last_event_ts, att.sessions)
    end
  end
end
