module BBBEvents
  class Attendee
    attr_accessor :id, :ext_user_id, :name, :moderator, :joins, :leaves, :duration, :recent_talking_time, :engagement

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
      # Convert recent_talking_time to human readable time
      if hash["recent_talking_time"] > 0
        hash["recent_talking_time"] = Time.at(hash["recent_talking_time"])
      else
        hash["recent_talking_time"] = ""
      end
      hash
    end

    def to_json
      hash = {}
      instance_variables.each { |var| hash[var[1..-1]] = instance_variable_get(var) }
      if hash["recent_talking_time"] > 0
        hash["recent_talking_time"] = Time.at(hash["recent_talking_time"])
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
