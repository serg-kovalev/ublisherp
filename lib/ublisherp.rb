require 'bundler/setup'
Bundler.require :default

require 'redis'
require 'redis-namespace'
require 'multi_json'
require 'oj'
require 'active_support/all'

MultiJson.use :oj

module Ublisherp

  mattr_accessor :redis

  def self.redis
    @@redis ||= Redis::Namespace.new(:ublisherp, Redis.new)
  end
end

Dir[File.join(File.dirname(__FILE__), 'ublisherp/*.rb')].each do |fn|
  require_relative "./ublisherp/#{File.basename(fn, '.rb')}"
end
