require File.expand_path('../content_item', __FILE__)

class Section < ActiveRecord::Base
  include Ublisherp::PublishableWithInstanceShortcuts

  has_many :content_items

  publish_associations :content_items, dependent: true
  unpublish_associations :content_items
  publish_stream
  publish_stream_of_model ContentItem
  publish_stream_of_model InheritedContentItem, if: -> ici { ici.hmm? }
  publish_stream name: :if_stream_in, if: ->(m) { true }
  publish_stream name: :if_stream_out, if: ->(m) { false }
  publish_stream name: :unless_stream_in, unless: ->(m) { false }
  publish_stream name: :unless_stream_out, unless: ->(m) { true }
  publish_stream name: :class_stream, class: [Class.new]
  publish_stream name: :visible_content_items, class: ContentItem, if: -> ci {
    ci.visible?
  }
end
