module BBBEvents
  class Poll
    attr_accessor :start, :published, :options, :votes

    def initialize(poll_event)
      @published = false

      @options = JSON.parse(poll_event["answers"]).map { |opt| opt["key"] }
      @votes   = {}
    end

    def published?
      @published
    end
  end
end
