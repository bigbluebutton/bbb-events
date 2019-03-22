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

    def to_hash
      hash = {}
      instance_variables.each { |var| hash[var[1..-1]] = instance_variable_get(var) }
      hash
    end

    def to_json
      hash = {}
      instance_variables.each { |var| hash[var[1..-1]] = instance_variable_get(var) }
      puts hash.to_json
      hash.to_json
    end
  end
end
