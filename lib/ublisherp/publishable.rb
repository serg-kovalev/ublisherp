require 'securerandom'

module Ublisherp::Publishable
  extend ActiveSupport::Concern

  module ClassMethods
    def publish_associations(*assocs)
      @publish_associations ||= []
      @publish_associations.concat Array.new(assocs || [])
      @publish_associations
    end

    def publish_stream(name: :all, **options)
      @publish_streams ||= []

      @publish_streams << options.merge(name: name)
      @publish_streams.uniq!
    end

    def publish_streams; @publish_streams || []; end
  end

  def publisher
    @publisher ||=
      begin
        "#{self.class.name}Publisher".constantize.new self
      rescue NameError
        Ublisherp::Publisher.new self
      end
  end

  def publish!(**options)
    publisher.publish!(**options)
  end

  def unpublish!(**options)
    publisher.unpublish!(**options)
  end

  alias :to_publishable :to_json
end
