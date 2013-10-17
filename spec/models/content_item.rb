class ContentItem < ActiveRecord::Base
  include Hooks
  include Ublisherp::PublishableWithInstanceShortcuts

  belongs_to :section
  has_and_belongs_to_many :tags
  publish_associations :section, :tags
  publish_indexes :slug
  publish_indexes :visible
  publish_type_stream
  publish_type_stream name: :visible, if: :visible?

  %i[
    before_publish
    before_first_publish
    after_publish
    after_first_publish
    before_unpublish
    before_unpublish_commit
    after_unpublish
    before_add_to_stream
    before_first_add_to_stream
    before_add_to_type_stream
    before_first_add_to_type_stream
    after_add_to_stream
    after_add_to_type_stream
    after_first_add_to_stream
    after_first_add_to_type_stream
    after_remove_from_stream
    after_remove_from_type_stream
  ].each do |hook|
    m = :"#{hook}_callback_test"
    __send__ hook, m
    define_method(m) { |*| true }
  end

  def ublisherp_stream_score
    stream_score || 1234.56789
  end

end

class InheritedContentItem < ContentItem
  belongs_to :region

  publish_associations :region

  def hmm?
    true
  end
end
