require 'bundler/setup'
Bundler.require :default

module Ublisherp
end

Dir[File.join(File.dirname(__FILE__), 'ublisherp/*.rb')].each do |fn|
  require_relative "./ublisherp/#{File.basename(fn, '.rb')}"
end
