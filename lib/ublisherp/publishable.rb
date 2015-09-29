require 'set'
require 'securerandom'

module Ublisherp::Publishable
  extend ActiveSupport::Concern

  CLASS_ATTRIBUTE_SETS = [
    :publish_association_attrs,
    :unpublish_association_attrs,
    :publish_stream_specs,
    :publish_type_stream_specs,
    :publish_index_attrs
  ]

  included do
    CLASS_ATTRIBUTE_SETS.each do |attr|
      class_attribute attr
      self.__send__("#{attr}=", Set.new)
    end

    include Hooks
    define_hooks :before_publish, :before_first_publish, :after_publish,
      :after_first_publish, :before_unpublish_commit, :before_unpublish,
      :after_unpublish, :before_add_to_stream, :before_first_add_to_stream,
      :after_add_to_stream, :after_first_add_to_stream,
      :after_remove_from_stream, :before_add_to_type_stream,
      :before_first_add_to_type_stream, :after_add_to_type_stream,
      :after_first_add_to_type_stream, :after_remove_from_type_stream

    class << self
      alias_method_chain :inherited, :ublisherp_set_recreation
    end
  end

  module ClassMethods
    def inherited_with_ublisherp_set_recreation(subclass)
      CLASS_ATTRIBUTE_SETS.each do |attr|
        subclass.__send__("#{attr}=", Set.new(__send__(attr)))
      end

      inherited_without_ublisherp_set_recreation subclass
    end

    def publish_associations(*assocs, dependent)
      assocs ||= []
      self.publish_association_attrs.merge(assocs).tap do
        self.unpublish_association_attrs.merge(assocs) if dependent
      end
    end

    def unpublish_associations(*assocs)
      self.unpublish_association_attrs.merge assocs
    end

    def publish_stream(name, **options)
      name |=  :all
      self.publish_stream_specs.
        add Ublisherp::StreamSpec.new(options.merge(name: name))
    end

    def publish_stream_of_model(model_cls, *options)
      options = options.extract_options!
      options.merge! name: model_cls.model_name.plural.underscore.to_sym,
                     class: model_cls
      publish_stream **options
    end

    def publish_type_stream(name, *options)
      name ||= :all
      options = options.extract_options!
      self.publish_type_stream_specs.
        add Ublisherp::TypeStreamSpec.new(options.merge(name: name))
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


  def publish!(*options)
    options = options.extract_options!
    publisher.publish!(*options)
  end

  def unpublish!(*options)
    options = options.extract_options!
    publisher.unpublish!(*options)
  end

end
