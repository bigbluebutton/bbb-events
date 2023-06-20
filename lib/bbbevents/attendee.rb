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
      {
        id: @id,
        ext_user_id: @ext_user_id,
        name: @name,
        moderator: @moderator,
        joins: @joins,
        leaves: @leaves,
        duration: @duration,
        recent_talking_time: @recent_talking_time > 0 ? Time.at(@recent_talking_time) : '',
        engagement: @engagement,
        sessions: @sessions,
      }
    end

    def as_json
      {
        id: @id,
        ext_user_id: @ext_user_id,
        name: @name,
        moderator: @moderator,
        joins: @joins.map { |join| BBBEvents.format_datetime(join) },
        leaves: @leaves.map { |leave| BBBEvents.format_datetime(leave) },
        duration: @duration,
        recent_talking_time: @recent_talking_time > 0 ? BBBEvents.format_datetime(Time.at(@recent_talking_time)) : '',
        engagement: @engagement,
        sessions: @sessions.map { |key, session| {
            joins: session[:joins].map { |join| join.merge({ timestamp: BBBEvents.format_datetime(join[:timestamp])}) },
            lefts: session[:lefts].map { |leave| leave.merge({ timestamp: BBBEvents.format_datetime(leave[:timestamp])}) }
          }
        }
      }
    end

    def to_json
      JSON.generate(as_json)
    end

    private

    def seconds_to_time(seconds)
      [seconds / 3600, seconds / 60 % 60, seconds % 60].map { |t| t.floor.to_s.rjust(2, "0") }.join(':')
    end
  end
end
