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

    def publish_stream_of_model(model_cls, **options)
      options.merge! name: model_cls.model_name.plural.underscore.to_sym,
                     class: model_cls
      publish_stream **options
    end

    def publish_streams; @publish_streams || []; end

    def published_type
      self.name.underscore.to_sym
    end
  end

  def publisher
    @publisher ||=
      begin
        "#{self.class.name}Publisher".constantize.new self
      rescue NameError
        Ublisherp::Publisher.new self
      end
  end

  def publishable_json_options
    {}
  end

  def as_publishable(opts = {})
    opts.symbolize_keys!.merge! root: true
    opts.merge! publishable_json_options
    as_json(opts)
  end

end

module Ublisherp::PublishableWithInstanceShortcuts
  extend ActiveSupport::Concern

  include Ublisherp::Publishable


  def publish!(**options)
    publisher.publish!(**options)
  end

  def unpublish!(**options)
    publisher.unpublish!(**options)
  end

end
