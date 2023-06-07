require "spec_helper"

RSpec.describe BBBEvents::Poll do
  before(:all) do
    @poll = @sample.polls.first
  end

  context "#id" do
    it "should properly parse id." do
      expect(@poll.id).to eq("d2d9a672040fbde2a47a10bf6c37b6a4b5ae187f-1534433961845/1/1534434041159")
    end
  end

  context "#options" do
    it "should properly parse options." do
      expect(@poll.options).to be_a(Array)
      expect(@poll.options.empty?).to be false
    end
  end

  context "#votes" do
    it "should properly record votes." do
      expect(@poll.votes).to be_a(Hash)
      expect(@poll.votes.empty?).to be false
    end
  end

  context "#published?" do
    it "has published? alias." do
      expect(@poll).to respond_to(:published?)
    end
  end
end
