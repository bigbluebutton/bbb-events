require 'bbbevents/version'

module BBBEvents
  TIME_FORMAT = "%H:%M:%S"
  DATE_FORMAT = "%m/%d/%Y %H:%M:%S"
  UNKNOWN_DATE = "??/??/????"

  def self.to_iso8601(time)
    time.utc.to_datetime.iso8601(3)
  end

  def self.parse(events_xml)
    Recording.new(events_xml)
  end
end
