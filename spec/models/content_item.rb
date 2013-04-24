class ContentItem < ActiveRecord::Base
  include Ublisherp::Publishable

  has_and_belongs_to_many :tags
  publish_associations :tags

end
