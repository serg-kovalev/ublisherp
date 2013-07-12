class SimpleContentItem < Ublisherp::Model
  published_type :content_item
  belongs_to :section
  has_fields :cheese_breed
  has_many :tags

  scope :visible, -> { where(visible: true) }
end
