require "spec_helper"

RSpec.describe BBBEvents::Poll do
  before(:all) do
    @sample = BBBEvents.parse(file_fixture("typed-poll-test_maintenance_-events.xml"))
    @poll = @sample.polls.first
  end

  context "#id" do
    it "should properly parse id." do
      expect(@poll.id).to eq("cadbc22db763496dea1903f70d57c6ba45fbd4aa-1687461615811/1/1687461820257")
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
      expect(@poll.as_json[:start]).to eq('2023-06-22T19:23:40.000+00:00')
    end
  end

  context "#poll typed response format" do
    it "has correct question." do
      poll = @sample.polls.last
      expect(poll.as_json[:start]).to eq('2023-06-22T19:25:11.000+00:00')
      expect(poll.as_json[:type]).to eq('R-')
      expect(poll.as_json[:question]).to eq('what is your favorite drink?')
    end
  end
end
