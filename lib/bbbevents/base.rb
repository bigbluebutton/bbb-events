require 'bbbevents/version'

module BBBEvents
  TIME_FORMAT = "%H:%M:%S"
  DATE_FORMAT = "%m/%d/%Y %H:%M:%S"
  UNKNOWN_DATE = "??/??/????"

  def self.format_datetime(time)
    time.strftime('%Y-%m-%dT%H:%M:%S.%L%:z')
  end

  def self.parse(events_xml)
    Recording.new(events_xml)
  end
end
