module BBBEvents
  class RecordedSegment
    attr_accessor :start, :stop, :duration

    def initialize
      @stop = nil
      @duration = 0
    end

    def stop=(stop)
      @stop = stop
      @duration = (@stop - @start).to_i
    end

    def to_h
      hash = {}
      instance_variables.each { |var| hash[var[1..-1]] = instance_variable_get(var) }
      hash
    end

    def to_json
      hash = {}
      instance_variables.each { |var| hash[var[1..-1]] = instance_variable_get(var) }
      hash.to_json
    end
  end
end
