require 'set'
require 'securerandom'

module Ublisherp::Publishable
  extend ActiveSupport::Concern

  included do
    class_attribute :publish_association_attrs
    class_attribute :unpublish_association_attrs
    class_attribute :publish_stream_specs
    class_attribute :publish_index_attrs

    self.publish_association_attrs = Set.new
    self.unpublish_association_attrs = Set.new
    self.publish_stream_specs = Set.new
    self.publish_index_attrs = Set.new

    include Hooks
    define_hooks :before_publish, :before_first_publish, :after_publish,
      :after_first_publish, :before_unpublish_commit, :before_unpublish,
      :after_unpublish, :before_add_to_stream, :before_first_add_to_stream,
      :after_add_to_stream, :after_first_add_to_stream, :after_remove_from_stream
  end

  module ClassMethods
    def publish_associations(*assocs, dependent: false)
      assocs ||= []
      self.publish_association_attrs.merge(assocs).tap do
        self.unpublish_association_attrs.merge(assocs) if dependent
      end
    end

    def unpublish_associations(*assocs)
      self.unpublish_association_attrs.merge assocs
    end

    def publish_stream(name: :all, **options)
      self.publish_stream_specs.add Ublisherp::StreamSpec.new(options.merge(name: name))
    end

    def publish_stream_of_model(model_cls, **options)
      options.merge! name: model_cls.model_name.plural.underscore.to_sym,
                     class: model_cls
      publish_stream **options
    end

    def publish_indexes(*attrs)
      self.publish_index_attrs.merge attrs
    end

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

  def as_publishable_with_associations(opts = {})
    as_publishable(opts).tap do |p|
      p = p[p.keys.first] # get root hash
      assocs = self.class.reflect_on_all_associations.select { |a|
        publish_association_attrs.include? a.name
      }
      assocs.each do |a|
        case a.macro
        when :belongs_to
          o = self.__send__(a.name)
          p[:"#{a.name}_id"] = Ublisherp::RedisKeys.key_for(o) if o
        when :has_many, :has_and_belongs_to_many
          p[:"#{a.name}_ids"] = self.__send__(a.name).map { |i|
            Ublisherp::RedisKeys.key_for(i) if i
          }
        end
      end
    end
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
