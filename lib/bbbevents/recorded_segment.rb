module BBBEvents
  # A period in which the meeting was being recorded.
  class RecordedSegment
    attr_accessor :start, :stop

    def initialize(start)
      @start = start
      @stop  = nil
    end

    # Duration in seconds.
    def duration
      (@stop - @start).to_i
    end

    def to_h
      {
        start: @start,
        stop: @stop,
        duration: duration,
      }
    end

    def as_json
      {
        start: BBBEvents.format_datetime(@start),
        stop: BBBEvents.format_datetime(@stop),
        duration: duration,
      }
    end

    def to_json
      JSON.generate(as_json)
    end
  end
end
