module BBBEvents
  TIME_FORMAT = "%H:%M:%S"
  DATE_FORMAT = "%m/%d/%Y %H:%M:%S"
  UNKNOWN_DATE = "??/??/????"

  def self.parse(events_xml)
    Recording.new(events_xml)
  end
end


