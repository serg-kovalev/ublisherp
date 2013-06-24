require File.expand_path('../content_item', __FILE__)

class Section < ActiveRecord::Base
  include Ublisherp::PublishableWithInstanceShortcuts

  has_many :content_items

  publish_associations :content_items, dependent: true
  unpublish_associations :content_items
  publish_stream
  publish_stream_of_model ContentItem
  publish_stream_of_model InheritedContentItem
  publish_stream name: :if_stream, if: ->(m) { false }
  publish_stream name: :unless_stream, unless: ->(m) { true }
  publish_stream name: :class_stream, class: [Class.new]
end
