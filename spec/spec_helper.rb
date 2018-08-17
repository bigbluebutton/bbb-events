require "bundler/setup"
require "bbbevents"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:all) do
    @sample = BBBEvents.parse(file_fixture("sample.xml"))
  end
end

# Helper for accessing file fixtures.
def file_fixture(file)
  File.dirname(__FILE__) + "/fixtures/files/#{file}"
end
