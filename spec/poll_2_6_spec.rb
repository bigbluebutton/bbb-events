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

  context "#poll json timestamp format" do
    it "has fixed poll json timestamp format." do
      expect(@poll.as_json[:start]).to eq('2023-05-17T18:59:56.000+00:00')
    end
  end

  context "#poll typed response format" do
    it "has correct question." do
      poll = @sample.polls.last
      expect(poll.as_json[:start]).to eq('2023-05-17T19:00:49.000+00:00')
      expect(poll.as_json[:type]).to eq('R-')
      expect(poll.as_json[:question]).to eq('what is your name?')
    end
  end
end
