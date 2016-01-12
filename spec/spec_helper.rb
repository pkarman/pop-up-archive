ENV["RAILS_ENV"] ||= 'test'

require 'simplecov'
require 'coveralls'

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
  SimpleCov::Formatter::HTMLFormatter,
  Coveralls::SimpleCov::Formatter
]
SimpleCov.start 'rails' do
  add_filter "/admin/"             # 3rd party
  add_filter "/app/models/search/" # 3rd party
end

# require 'webmock'
# WebMock.disable_net_connect!(:allow_localhost => true)

require File.expand_path("../../config/environment", __FILE__)
require "rails/application"
require 'factory_girl'
require 'rspec/rails'
require 'rspec/mocks'
require 'rspec/its'
require 'capybara/rspec'
require 'capybara/rails'
require 'capybara/poltergeist'
require 'elasticsearch/extensions/test/cluster'
require 'database_cleaner'

DatabaseCleaner.strategy = :transaction

Capybara.register_driver :chrome do |app|
  Capybara::Selenium::Driver.new(app, :browser => :chrome)
end

Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, :inspector => true)
end

Capybara.default_driver = :poltergeist

def create_es_index(klass)
  errors = []
  completed = 0
  puts "Creating Index for class #{klass}"
  klass.__elasticsearch__.create_index! force: true, index: klass.index_name
  klass.__elasticsearch__.refresh_index!
  klass.__elasticsearch__.import  :return => 'errors', :batch_size => 200    do |resp|
    # show errors immediately (rather than buffering them)
    errors += resp['items'].select { |k, v| k.values.first['error'] }
    completed += resp['items'].size
    puts "Finished #{completed} items"
    STDERR.flush
    STDOUT.flush
    if errors.size > 0
      STDOUT.puts "ERRORS in #{$$}:"
      STDOUT.puts pp(errors)
    end
  end
  puts "Completed #{completed} records of class #{klass}"
end

def seed_test_db
  StripeMock.start
  print "Cleaning test db..."
  DatabaseCleaner.clean_with(:truncation)
  puts "done"
  print "Loading seed data into test db..."
  load Rails.root + "db/seeds.rb"
  puts "done"
  StripeMock.stop
end

def start_es_server
  elasticsearch = '/usr/local/bin/elasticsearch-1.5.2/bin/elasticsearch'
  Elasticsearch::Extensions::Test::Cluster.start(nodes: 1, command: elasticsearch) unless Elasticsearch::Extensions::Test::Cluster.running?

  # create index(s) to test against.
  create_es_index(Item)
end

def stop_es_server
  Elasticsearch::Extensions::Test::Cluster.stop if Elasticsearch::Extensions::Test::Cluster.running?
end

RSpec.configure do |config|
  config.include Capybara::DSL
  config.mock_with :rspec
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!

  config.raise_errors_for_deprecations!  # catastrophe is a Good Thing

  # back-compat for our version-2-era tests
  config.expect_with(:rspec) { |c| c.syntax = [:should, :expect] }
  config.mock_with :rspec do |mocks|
    mocks.syntax = [:should, :expect]
    mocks.verify_partial_doubles = true
  end

  config.include Devise::TestHelpers, type: :controller
  Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f }
  FactoryGirl.reload

  config.before :suite do
    seed_test_db
    start_es_server unless ENV['ES_SKIP']
  end

  config.after :suite do
    stop_es_server unless ENV['ES_SKIP']
  end

end

def test_file(ff)
  File.expand_path(File.dirname(__FILE__) + '/factories/files/' + ff)
end
