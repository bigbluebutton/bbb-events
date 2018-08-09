module BBBEvents
  class Attendee
    attr_accessor :id, :name, :moderator, :joins, :leaves, :duration, :recent_talking_time, :engagement

    MODERATOR_ROLE = "MODERATOR"
    VIEWER_ROLE = "VIEWER"

    def initialize(join_event)
      @id        = join_event["userId"]
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
        talk_time_format,
        join_format,
        left_format,
        duration_format,
      ].map(&:to_s)
    end

    # Helper to format first join.
    def join_format(format = DATE_FORMAT)
      Time.at(@joins.first).strftime(format)
    end

    # Helper to format last leave.
    def left_format(format = DATE_FORMAT)
      return UNKNOWN_DATE if @leaves.empty?
      Time.at(@leaves.last).strftime(format)
    end

    # Helper to format the duration (stored in seconds).
    def duration_format(format = TIME_FORMAT)
      Time.at(@duration).utc.strftime(format)
    end

    # Helper to format the talk time (stored in seconds).
    def talk_time_format(format = TIME_FORMAT)
      Time.at(@engagement[:talk_time]).utc.strftime(format)
    end
  end
end
