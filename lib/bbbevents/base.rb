require 'bbbevents/version'

module BBBEvents
  
  class << self
    def parse(obj)
      raise 'BBBEvents: Invalid file.' unless File::file?(obj)
      RecordingData.new(obj)
    end
  end
  
end

require 'bbbevents/recording_data'
