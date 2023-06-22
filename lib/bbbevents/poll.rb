module BBBEvents
  class Poll
    attr_accessor :id, :type, :question, :start, :published, :options, :votes

    def initialize(poll_event)
      @id        = poll_event["pollId"]
      @type      = poll_event["type"]
      @question  = poll_event["question"].nil? ? "" : "#{poll_event['question']}"
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
        type: @type,
        question: @question,
        published: @published,
        options: @options,
        start: BBBEvents.format_datetime(@start),
        votes: @votes
      }
    end
  end
end
