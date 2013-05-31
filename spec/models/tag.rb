class Tag < ActiveRecord::Base
  include Ublisherp::PublishableWithInstanceShortcuts

  has_and_belongs_to_many :content_items

  publish_stream
end
