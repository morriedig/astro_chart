ENV["RACK_ENV"] = "test"

require "tmpdir"
require "fileutils"

# Isolate the SQLite store to a throwaway file before the app (which builds
# its store at class-load time) is required.
TEST_DB_PATH = File.join(Dir.mktmpdir("astro-test"), "test.db")
ENV["ASTRO_DB_PATH"] = TEST_DB_PATH

require "rspec"
require "rack/test"
require "json"
require_relative "../app"

RSpec.configure do |config|
  config.include Rack::Test::Methods

  # Each example starts from an empty store so usage/key state never leaks.
  config.before(:each) { AstroWeb.store.reset! }
  config.after(:suite) do
    dir = File.dirname(TEST_DB_PATH)
    FileUtils.remove_entry(dir) if File.directory?(dir)
  end

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.disable_monkey_patching!
  config.order = :defined
end
