class ContentItem < ActiveRecord::Base
  include Ublisherp::PublishableWithInstanceShortcuts

  has_and_belongs_to_many :tags
  publish_associations :tags

  def ublisherp_stream_score
    1234.56789
  end
end
