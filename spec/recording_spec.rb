require "spec_helper"

RSpec.describe BBBEvents::Recording do
  context "#metadata" do
    it "should properly parse metadata." do
      expect(@sample.metadata).to eql({
        "gl_listed": "false",
        isBreakout: "false",
        meetingName: "Home Room",
        meetingId: "ae5e285551844c61c757f4c8f233850a2e0b16bf",
      }.with_indifferent_access)
    end
  end

  context "#meeting_id" do
    it "should properly parse meeting_id." do
      expect(@sample.meeting_id).to eql("ae5e285551844c61c757f4c8f233850a2e0b16bf")
    end
  end

  context "#timestamp" do
    it "should properly parse timestamp." do
      expect(@sample.timestamp).to eql(1534433961829)
    end
  end

  context "#start" do
    it "should properly parse start time." do
      expect(@sample.start).to eql(Time.new(2018, 8, 16, 11, 39, 21, "-04:00"))
    end
  end

  context "#finish" do
    it "should properly parse finish time." do
      expect(@sample.finish).to eql(Time.new(2018, 8, 16, 11, 40, 58, "-04:00"))
    end
  end

  context "#duration" do
    it "should properly parse duration." do
      expect(@sample.duration).to eql(97)
    end
  end

  context "#attendees" do
    it "should be an Array." do
      expect(@sample.moderators).to be_an(Array)
    end

    it "should properly parse list of attendees." do
      expect(@sample.attendees).to all(be_an_instance_of(BBBEvents::Attendee))
    end
  end

  context "#moderators" do
    it "should be an Array." do
      expect(@sample.moderators).to be_an(Array)
    end

    it "should filter moderators from attendees." do
      @sample.moderators.each do |att|
        expect(att.moderator?).to be true
      end
    end
  end

  context "#viewers" do
    it "should be an Array." do
      expect(@sample.viewers).to be_an(Array)
    end

    it "should filter viewers from attendees." do
      @sample.viewers.each do |att|
        expect(att.moderator?).to be false
      end
    end
  end

  context "#polls" do
    it "should be an Array." do
      expect(@sample.polls).to be_an(Array)
    end

    it "should properly parse list of polls." do
      expect(@sample.polls).to all(be_an_instance_of(BBBEvents::Poll))
    end
  end

  context "#published_polls" do
    it "should be an Array." do
      expect(@sample.published_polls).to be_an(Array)
    end

    it "should filter published polls from polls." do
      @sample.published_polls.each do |poll|
        expect(poll.published?).to be true
      end
    end
  end

  context "#unpublished_polls" do
    it "should be an Array." do
      expect(@sample.unpublished_polls).to be_an(Array)
    end

    it "should filter unpublished polls from polls." do
      @sample.unpublished_polls.each do |poll|
        expect(poll.published?).to be false
      end
    end
  end

  context "#files" do
    it "should properly parse uploaded file names." do
      expect(@sample.files).to contain_exactly("default.pdf")
    end
  end

  context "#create_csv" do
    before(:all) do
      @csv_path = File.dirname(__FILE__) + "/testing.csv"
      @sample.create_csv(@csv_path)
    end

    after(:all) do
      File.delete(@csv_path) if File.exist?(@csv_path)
    end

    it "should generate csv file." do
      expect(File).to exist(@csv_path)
    end

    it "should include corrent number of polls." do
      written_polls = CSV.read(@csv_path).first.select { |h| h[/Poll \d/] }.length
      expect(written_polls).to eql(@sample.polls.length)
    end

    it "should write correct data." do
      first_user = CSV.read(@csv_path)[1]
      csv_row = @sample.attendees.first.csv_row
      expect(csv_row).to eql(first_user[0...csv_row.length])
    end
  end
end
