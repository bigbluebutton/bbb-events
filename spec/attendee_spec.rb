require "spec_helper"

RSpec.describe BBBEvents::Attendee do
  before(:all) do
    @attendee = @sample.attendees.first
  end

  context "#id" do
    it "should properly parse id." do
      expect(@attendee.id).to eql("w_k961xjhcwvn2")
    end
  end

  context "#name" do
    it "should properly parse name." do
      expect(@attendee.name).to eql("Tim")
    end
  end

  context "#moderator" do
    it "should properly parse role." do
      expect(@attendee.moderator).to be true
    end
  end

  context "#joined" do
    it "should properly parse join time." do
      expect(@attendee.joined).to eql(Time.new(2018, 8, 16, 11, 39, 21))
    end
  end

  context "#left" do
    it "should properly parse leave time." do
      expect(@attendee.left).to eql(Time.new(2018, 8, 16, 11, 40, 58))
    end
  end

  context "#moderator?" do
    it "has moderator? alias." do
      expect(@attendee).to respond_to(:moderator?)
    end
  end
end
