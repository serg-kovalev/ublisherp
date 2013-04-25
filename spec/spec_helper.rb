require 'rubygems'
require 'bundler/setup'
Bundler.require :default, :development

require 'pry'
require 'pry-debugger'
require 'active_record'
require 'rspec'
require 'sqlite3'

RSpec.configure do |config|
  # config.treat_symbols_as_metadata_keys_with_true_values = true
  # config.run_all_when_everything_filtered = true
  # config.filter_run :focus

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = 'random'

  config.before :all do
    $redis = Redis.new(db: 15)
    Ublisherp.redis = $redis

    ActiveRecord::Base.establish_connection(
      adapter: "sqlite3",
      database: ":memory:"
    )

    load './spec/migrate.rb'
  end

  config.before :each do
    $redis.flushdb
  end
end

require_relative '../lib/ublisherp'

Dir["./spec/models/*.rb"].each {|file| require file }
