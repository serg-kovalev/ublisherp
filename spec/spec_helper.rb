require 'rubygems'
require 'bundler/setup'
Bundler.require :default, :test

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

    ActiveRecord::Base.establish_connection(
      adapter: "sqlite3",
      database: ":memory:"
    )

    require 'migrate'
  end

  config.before :each do
    $redis.flushdb
  end
end

require_relative '../lib/ublisherp'

Dir["./spec/models/*.rb"].each {|file| require file }
