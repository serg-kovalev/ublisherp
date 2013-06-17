class ContentItem < ActiveRecord::Base
  include Ublisherp::PublishableWithInstanceShortcuts

  belongs_to :section
  has_and_belongs_to_many :tags
  publish_associations :section, :tags
  publish_indexes :slug

  def ublisherp_stream_score
    stream_score || 1234.56789
  end
end

class InheritedContentItem < ContentItem
end
