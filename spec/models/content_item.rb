class ContentItem < ActiveRecord::Base
  include Hooks
  include Ublisherp::PublishableWithInstanceShortcuts

  belongs_to :section
  has_and_belongs_to_many :tags
  publish_associations :section, :tags
  publish_indexes :slug
  publish_indexes :visible

  before_publish :before_publish_callback_test
  before_first_publish :before_first_publish_callback_test
  after_publish :after_publish_callback_test
  after_first_publish :after_first_publish_callback_test
  before_unpublish :before_unpublish_callback_test
  before_unpublish_commit :before_unpublish_commit_callback_test
  after_unpublish :after_unpublish_callback_test
  before_add_to_stream :before_add_to_stream_callback_test
  before_first_add_to_stream :before_first_add_to_stream_callback_test
  after_add_to_stream :after_add_to_stream_callback_test
  after_first_add_to_stream :after_first_add_to_stream_callback_test
  after_remove_from_stream :after_remove_from_stream_callback_test

  def ublisherp_stream_score
    stream_score || 1234.56789
  end

  def before_publish_callback_test(*); end
  def before_first_publish_callback_test(*); end
  def after_publish_callback_test(*); end
  def after_first_publish_callback_test(*); end
  def before_unpublish_callback_test(*); end
  def before_unpublish_commit_callback_test(*); end
  def after_unpublish_callback_test(*); end
  def before_add_to_stream_callback_test(*); end
  def after_add_to_stream_callback_test(*); end
  def before_first_add_to_stream_callback_test(*); end
  def after_first_add_to_stream_callback_test(*); end
  def after_remove_from_stream_callback_test(*); end
end

class InheritedContentItem < ContentItem
end
