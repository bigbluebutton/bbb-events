require "spec_helper"
require "tempfile"

RSpec.describe BBBEvents::RecordedSegment do
  # Parses an events.xml with the given events, for a meeting that starts at
  # 2017-07-14 02:40:00 UTC. The first event is at that instant.
  def recording_with(*events)
    file = Tempfile.new(["events", ".xml"])
    file.write(<<~XML)
      <?xml version="1.0" encoding="UTF-8"?>
      <recording meeting_id="abc-1500000000000" bbb_version="2.6.0">
        <metadata meetingId="abc" meetingName="Test"/>
        <meeting id="abc-1500000000000" externalId="abc" name="Test" breakout="false"/>
        #{events.join("\n  ")}
      </recording>
    XML
    file.close
    BBBEvents.parse(file.path)
  ensure
    file&.unlink
  end

  def record_status(timestamp, status)
    %(<event timestamp="#{timestamp}" module="PARTICIPANT" eventname="RecordStatusEvent"><userId>w_1</userId><status>#{status}</status></event>)
  end

  context "#recorded_segments" do
    it "should properly parse recorded segments." do
      expect(@sample.recorded_segments.length).to eql(1)

      segment = @sample.recorded_segments.first
      expect(segment.start).to eql(Time.parse("2018-08-16 15:39:47 UTC"))
      expect(segment.stop).to eql(Time.parse("2018-08-16 15:40:54 UTC"))
      expect(segment.duration).to eql(67)
    end

    it "should end a recording that was never stopped with the meeting." do
      recording = BBBEvents.parse(file_fixture("typed-poll-test_maintenance_-events.xml"))

      expect(recording.recorded_segments.length).to eql(1)
      expect(recording.recorded_segments.first.stop).to eql(recording.finish)
      expect(recording.recorded_segments.first.duration).to eql(310)
    end

    it "should ignore a start while recording and a stop while not recording." do
      recording = recording_with(
        record_status(0, false),
        record_status(1000, true),
        record_status(2000, true),
        record_status(4000, false),
        record_status(5000, false),
        record_status(7000, true),
        %(<event timestamp="9000" module="PARTICIPANT" eventname="EndAndKickAllEvent"/>),
      )

      meeting_start = Time.parse("2017-07-14 02:40:00 UTC")
      expect(recording.recorded_segments.map { |s| [s.start - meeting_start, s.stop - meeting_start] }).to eql([[1.0, 4.0], [7.0, 9.0]])
      expect(recording.recorded_segments.map(&:duration)).to eql([3, 2])
    end

    it "should not create segments when the meeting was not recorded." do
      recording = recording_with(%(<event timestamp="0" module="PARTICIPANT" eventname="EndAndKickAllEvent"/>))

      expect(recording.recorded_segments).to eql([])
    end
  end

  context "#as_json" do
    it "should include recorded segments in the recording JSON." do
      segment = JSON.parse(@sample.to_json)["recorded_segments"].first

      expect(segment["start"]).to match(/\A\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}[+-]\d\d:\d\d\z/)
      expect(Time.parse(segment["start"])).to eql(Time.parse("2018-08-16 15:39:47 UTC"))
      expect(Time.parse(segment["stop"])).to eql(Time.parse("2018-08-16 15:40:54 UTC"))
      expect(segment["duration"]).to eql(67)
    end
  end
end
