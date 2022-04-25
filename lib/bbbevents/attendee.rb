module BBBEvents
  class Attendee
    attr_accessor :id, :ext_user_id, :name, :moderator, :joins, :leaves, :duration, :recent_talking_time, :engagement, :sessions

    MODERATOR_ROLE = "MODERATOR"
    VIEWER_ROLE = "VIEWER"

    def initialize(join_event)
      @id        = join_event["userId"]
      @ext_user_id = join_event["externalUserId"]
      @name      = join_event["name"]
      @moderator = (join_event["role"] == MODERATOR_ROLE)

      @joins    = []
      @leaves   = []
      @duration = 0

      @recent_talking_time = 0

      @engagement = {
        chats: 0,
        talks: 0,
        raisehand: 0,
        emojis: 0,
        poll_votes: 0,
        talk_time: 0,
      }

      # A hash of join and lefts arrays for each internal user id
      # { "w_5lmcgjboagjc" => { :joins => [], :lefts => []}}
      @sessions = Hash.new
    end

    def moderator?
      moderator
    end

    # Grab the initial join.
    def joined
      @joins.first
    end

    # Grab the last leave.
    def left
      @leaves.last
    end

    def csv_row
      e = @engagement
      [
        @name,
        @moderator,
        e[:chats],
        e[:talks],
        e[:emojis],
        e[:poll_votes],
        e[:raisehand],
        seconds_to_time(@engagement[:talk_time]),
        joined.strftime(DATE_FORMAT),
        left.strftime(DATE_FORMAT),
        seconds_to_time(@duration),
      ].map(&:to_s)
    end

    def to_h
      hash = {}
      instance_variables.each { |var| hash[var[1..-1]] = instance_variable_get(var) }

      # Convert timestamps to "2021-09-23T16:08:29.000+00:00" format
      joins_arr = []
      @joins.each { |j|
        joins_arr.append(BBBEvents.format_datetime(j))
      }
      hash["joins"] = joins_arr

      leaves_arr = []
      @leaves.each { |l|
        leaves_arr.append(BBBEvents.format_datetime(l))
      }
      hash["leaves"] = leaves_arr

      @sessions.each_value { |val|
        val[:joins].each { |j|
          j[:timestamp] = BBBEvents.format_datetime(j[:timestamp])
        }
        val[:lefts].each { |j|
          j[:timestamp] = BBBEvents.format_datetime(j[:timestamp])
        }
      }

      # Convert timestamps to "2021-09-23T16:08:29.000+00:00" format
      if hash["recent_talking_time"] > 0
        hash["recent_talking_time"] = BBBEvents.format_datetime(Time.at(hash["recent_talking_time"]))
      else
        hash["recent_talking_time"] = ""
      end
      hash
    end

    def to_json
      hash = {}
      instance_variables.each { |var| hash[var[1..-1]] = instance_variable_get(var) }
      # Convert timestamps to "2021-09-23T16:08:29.000+00:00" format
      if hash["recent_talking_time"] > 0
        hash["recent_talking_time"] = BBBEvents.format_datetime(Time.at(hash["recent_talking_time"]))
      else
        hash["recent_talking_time"] = ""
      end
      hash.to_json
    end

    private

    def seconds_to_time(seconds)
      [seconds / 3600, seconds / 60 % 60, seconds % 60].map { |t| t.floor.to_s.rjust(2, "0") }.join(':')
    end
  end
end
