class Section < ActiveRecord::Base
  include Ublisherp::PublishableWithInstanceShortcuts

  has_many :content_items

  publish_stream
end
