class ContentItem < ActiveRecord::Base
  # Rails methods
  has_and_belongs_to_many :tags

  # Ublisherp methods
  publish_associations :tags
end

class Tag < ActiveRecord::Base
  # Rails methods
  has_and_belongs_to_many :content_items
  
  # Ublisherp methods
  # Tag will by default have a stream of content_items and other associations
  publish_stream # default: stream name is 'all', all associations passed
  publish_stream name: :stuff, assocs: [:cards, :bikes]

  publish_stream name: :articles, assocs: [:articles]
  # or
  publish_stream :articles

  publish_stream name: :weird, if: ->(a) { a.weird? }
  # or
  publish_stream name: :weird, if: :weird?

end

class Story < ActiveRecord::Base
end
