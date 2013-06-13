class SimpleContentItem < Ublisherp::Model
  published_type :content_item
  belongs_to :section
  has_many :tags
end
