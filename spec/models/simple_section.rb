class SimpleSection < Ublisherp::Model
  published_type :section
  has_stream :content_items, limit_count: 1
  has_fields :enabled
end
