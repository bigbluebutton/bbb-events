require "spec_helper"

RSpec.describe BBBEvents::Recording do
  context "talk time" do
    before(:all) do
      recording = BBBEvents.parse(file_fixture("talking.xml"))
      @attendees = recording.attendees.to_h { |a| [a.name, a] }
    end

    it "counts a talk still open when the meeting ends" do
      expect(@attendees["Ana"].engagement[:talks]).to eql(1)
      expect(@attendees["Ana"].engagement[:talk_time]).to eql(60)
    end

    it "closes a talk when the user leaves the voice conference" do
      # 10s until the mute + 2s from the late talking=true to leaving voice
      expect(@attendees["Bruno"].engagement[:talk_time]).to eql(12)
    end

    it "does not count leaving the voice conference as leaving the meeting" do
      expect(@attendees["Bruno"].leaves.length).to eql(1)
    end

    it "closes a talk on unmute" do
      # 2s until the mute + 2s from the late talking=true to the unmute + 3s
      expect(@attendees["Carla"].engagement[:talks]).to eql(3)
      expect(@attendees["Carla"].engagement[:talk_time]).to eql(7)
    end

    it "closes a talk on leaving the voice conference in a BBB 2.0 recording" do
      jeff = @sample.attendees.find { |a| a.name == "Jeff" }
      expect(jeff.engagement[:talk_time]).to eql(5)
    end
  end
end
