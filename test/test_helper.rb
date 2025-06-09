ENV["RAILS_ENV"] ||= "test"

# Configure SimpleCov before requiring any application files
require "simplecov"

SimpleCov.start "rails" do
  # Enable branch coverage tracking
  enable_coverage :branch

  # Set minimum coverage threshold to 95%
  minimum_coverage 95
  minimum_coverage_by_file 90

  # Enable merging for parallel test support
  use_merging true

  # Add exclusions for typical Rails files that don't need testing
  add_filter "/config/"
  add_filter "/db/"
  add_filter "/vendor/"
  add_filter "/bin/"
  add_filter "/script/"
  add_filter "/app/channels/application_cable/"
  add_filter "/app/jobs/application_job.rb"
  add_filter "/app/mailers/application_mailer.rb"
  add_filter "/app/models/application_record.rb"
end

require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Configure SimpleCov for parallel test execution
    parallelize_setup do |worker|
      SimpleCov.command_name "#{SimpleCov.command_name}-#{worker}"
    end

    parallelize_teardown do |worker|
      SimpleCov.result

      # Show detailed coverage only from the main process after all workers finish
      if worker == 1
        sleep 0.1 # Give a moment for coverage to be written
        if File.exist?("coverage/index.html") && File.exist?("bin/coverage")
          puts ""
          system("bin/coverage")
        end
      end
    end

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
