class Tag < ActiveRecord::Base
  include Ublisherp::Publishable

  has_and_belongs_to_many :content_items
end
