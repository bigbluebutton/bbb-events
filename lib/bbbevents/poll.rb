module BBBEvents
  class Poll
    attr_accessor :id, :start, :published, :options, :votes

    def initialize(poll_event)
      @id        = poll_event["pollId"]
      @published = false
      @options   = JSON.parse(poll_event["answers"]).map { |opt| opt["key"] }
      @votes     = {}
    end

    def published?
      @published
    end

    def to_h
      hash = {}
      instance_variables.each { |var| hash[var[1..-1]] = instance_variable_get(var) }
      hash
    end
    alias_method :as_json, :to_h

    def to_json
      JSON.generate(as_json)
    end

    def as_json
      {
        id: @id,
        published: @published,
        options: @options,
        start: BBBEvents.format_datetime(@start),
        votes: @votes
      }
    end
  end
end
