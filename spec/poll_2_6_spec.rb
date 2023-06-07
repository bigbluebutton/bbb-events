require "spec_helper"

RSpec.describe BBBEvents::Poll do
  before(:all) do
    @sample = BBBEvents.parse(file_fixture("new-events-2_6.xml"))
    @poll = @sample.polls.first
  end

  context "#id" do
    it "should properly parse id." do
      expect(@poll.id).to eq("bd5a59a3f61d1ec7402cf9105a090e84f867421f-1684349961676/1/1684349997071")
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
