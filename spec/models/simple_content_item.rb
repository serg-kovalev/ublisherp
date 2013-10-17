class SimpleContentItem < Ublisherp::Model
  published_type :content_item
  belongs_to :section
  has_fields :cheese_breed
  has_fields :enabled, default: true
  has_many :tags
  has_type_stream :visible

  scope :visible, -> { where(visible: true) }
end
