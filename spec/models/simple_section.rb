class SimpleSection < Ublisherp::Model
  published_type :section
  has_stream :content_items
end
