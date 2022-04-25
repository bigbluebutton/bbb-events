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
        # convert to "2021-09-23T16:08:29.000+00:00" format
        start: BBBEvents.to_iso8601(@start),
        finish: BBBEvents.to_iso8601(@finish),

        attendees: attendees.map(&:to_h),
        files: @files,
        polls: polls.map(&:to_h)
      }
    end

    def to_json
      to_h.to_json
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

    def calculate_user_duration_based_on_userid(last_event_ts, sessions)
      # combine join and left events into an array
      joins_lefts_arr = build_join_lefts_array(last_event_ts, sessions)

      # sort the events
      joins_lefts_arr_sorted = joins_lefts_arr.sort_by { |event| event[:timestamp] }

      combined_tuples = combine_tuples_by_userid(sessions)
      combined_tuples_sorted = fill_missing_left_events(combined_tuples)

      prepare_joins_lefts_for_overlap_checks(joins_lefts_arr_sorted)
      mark_overlapping_events(combined_tuples_sorted, joins_lefts_arr_sorted)
      removed_overlap_events = remove_overlapping_events(joins_lefts_arr_sorted)

      duration_tuples = build_join_left_tuples(removed_overlap_events)

      partial_duration = 0
      duration_tuples.each do |tuple|
        duration = tuple[:left][:timestamp].to_i - tuple[:join][:timestamp].to_i
        partial_duration += duration
      end

      partial_duration
    end

    def tuples_by_userid(joins_arr, lefts_arr)
      joins_length = joins_arr.length - 1
      tuples = []
      for i in 0..joins_length
        tuple = {:join => joins_arr[i], :left => nil}

        if i <= lefts_arr.length - 1
          tuple[:left] = lefts_arr[i]
        end
        tuples.append(tuple)
      end
      tuples
    end

    def combine_tuples_by_userid(user_sessions)
      combined_tuples = []

      user_sessions.each do | userid, joins_lefts |
        joins_lefts_arr = []
        joins_lefts[:joins].each { |j| joins_lefts_arr.append(j)}
        joins_lefts[:lefts].each { |j| joins_lefts_arr.append(j)}

        tuples = tuples_by_userid(joins_lefts[:joins], joins_lefts[:lefts])

        tuples.each do |tuple|
          combined_tuples.append(tuple)
        end
      end

      combined_tuples
    end

    def fill_missing_left_events(combined_tuples)
      joins_lefts_arr_sorted = combined_tuples.sort_by { |event| event[:join][:timestamp]}

      joins_lefts_arr_sorted_length = joins_lefts_arr_sorted.length - 1
      for i in 0..joins_lefts_arr_sorted_length
        cur_event = joins_lefts_arr_sorted[i]
        if cur_event[:left].nil?
          unless joins_lefts_arr_sorted_length == i
            # Take the next event as the left event for this current event
            next_event = joins_lefts_arr_sorted[i + 1]
            left_event = {:timestamp => next_event[:timestamp], :userid => cur_event[:userid], :event => :left}

            cur_event[:left] = left_event
          end
        end
      end

      joins_lefts_arr_sorted
    end

    def build_join_left_tuples(joins_lefts_arr_sorted)
      jl_tuples = []
      jl_tuple = {:join => nil, :left => nil}
      loop_state = :find_join

      events_length = joins_lefts_arr_sorted.length - 1
      for i in 0..events_length

        cur_event = joins_lefts_arr_sorted[i]

        if loop_state == :find_join and cur_event[:event] == :join
          jl_tuple[:join] = cur_event
          loop_state = :find_left
        end

        next_event = nil
        if i < events_length
          next_event = joins_lefts_arr_sorted[i + 1]
        end

        if loop_state == :find_left
          if next_event != nil and next_event[:event] == :left
            # skip the current event to get to the next event
          elsif (cur_event[:event] == :left and next_event != nil and next_event[:event] == :join) or (i == events_length)
            jl_tuple[:left] = cur_event
            jl_tuples.append(jl_tuple)
            jl_tuple = {:join => nil, :left => nil}
            loop_state = :find_join
          end
        end
      end

      jl_tuples
    end

    def build_join_lefts_array(last_event_timestamp, user_session)
      joins_leaves_arr = []
      lefts_count = 0
      joins_count = 0

      user_session.each do | userid, joins_lefts |
        lefts_count += joins_lefts[:lefts].length
        joins_count += joins_lefts[:joins].length
        joins_lefts[:joins].each { |j| joins_leaves_arr.append(j)}
        joins_lefts[:lefts].each { |j| joins_leaves_arr.append(j)}
      end

      if joins_count > lefts_count
        last_event = joins_leaves_arr[-1]
        joins_leaves_arr.append({:timestamp => last_event_timestamp, :userid => "    system    ", :ext_userid=> last_event[:ext_userid], :event => :left})
      end

      joins_leaves_arr
    end

    def prepare_joins_lefts_for_overlap_checks(joins_leaves_arr_sorted)
      joins_leaves_arr_sorted.each do |event|
        event[:remove] = false
      end
    end

    def mark_overlapping_events(combined_tuples_sorted, joins_leaves_arr_sorted)
      combined_tuples_sorted.each do |ce|
        joins_leaves_arr_sorted.each do |jl|
          event_ts = jl[:timestamp].to_i
          ce_join = ce[:join][:timestamp].to_i

          if event_ts > ce_join and not ce[:left].nil? and event_ts < ce[:left][:timestamp].to_i
            jl[:remove] = true
          end
        end
      end
    end

    def remove_overlapping_events(joins_leaves_arr_sorted)
      keep_events = []
      joins_leaves_arr_sorted.each do |ev|
        if not ev[:remove]
          keep_events.append(ev)
        end
      end
      keep_events
    end

    def build_tuples_of_kept_events(kept_events)
      odd_events = []
      even_events = []
      for i in 0..kept_events.length - 1
        odd_even = i + 1
        if odd_even.even?
          even_events.append(kept_events[i])
        else
          odd_events.append(kept_events[i])
        end
      end

      tuples = []
      for i in 0..odd_events.length - 1
        tuple = {:start => odd_events[i], :end => even_events[i]}
        tuples.append(tuple)
      end

      tuples
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
    def total_duration(last_event_ts, att)
      calculate_user_duration_based_on_userid(last_event_ts, att.sessions)
    end
  end
end
