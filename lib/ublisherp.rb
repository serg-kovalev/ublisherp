require 'bundler/setup'
Bundler.require :default

require 'redis'
require 'redis-namespace'
require 'multi_json'
require 'oj'
require 'active_support/all'
require 'hooks'
require 'thread'

MultiJson.use :oj

module Ublisherp

  mattr_accessor :redis_url, :redis_namespace

  self.redis_url = "redis://127.0.0.1:6379/0"
  self.redis_namespace = :ublisherp

  def self.redis
    Thread.current[:ublisherp_redis] ||=
      Redis::Namespace.new(redis_namespace, redis: Redis.new(url: redis_url))
  end

  def self.reconnect_redis
    Thread.current[:ublisherp_redis] = nil
    redis
  end

  if defined?(Rails)
    require "action_controller/railtie"

    class Railtie < Rails::Railtie
      config.action_dispatch.rescue_responses.merge!(
        'Ublisherp::Model::RecordNotFound' => :not_found
      )
    end
  end
end

Dir[File.join(File.dirname(__FILE__), 'ublisherp/*.rb')].each do |fn|
  require_relative "./ublisherp/#{File.basename(fn, '.rb')}"
end
