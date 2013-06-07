class Section < ActiveRecord::Base
  include Ublisherp::PublishableWithInstanceShortcuts

  has_many :content_items

  publish_stream
  publish_stream name: :if_stream, if: ->(m) { false }
  publish_stream name: :unless_stream, unless: ->(m) { true }
  publish_stream name: :class_stream, class: [Class.new]
end
