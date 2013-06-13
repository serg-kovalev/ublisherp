require 'set'

require 'active_model/naming'
require 'active_model/conversion'

class Ublisherp::Model < OpenStruct
  include Ublisherp

  extend ActiveModel::Naming
  include ActiveModel::Conversion

  class RecordNotFound < StandardError; end

  class << self

    include Ublisherp

    def published_type(name=nil)
      if name
        @published_type = name
        @@published_types ||= {}
        @@published_types[@published_type] = self
      end
      @published_type || self.name.underscore.to_sym
    end

    def published_types
      @@published_types ||= {}
    end

    def find(id)
      data_key = if id.is_a?(Hash)
                   if id.size != 1
                     raise NotImplementedError,
                       "find can only have one index condition for now"
                   end

                   Ublisherp.redis.srandmember(
                     RedisKeys.key_for_index(self, id.keys.first,
                                             id.values.first))
                 else
                   RedisKeys.key_for(self, id: id)
                 end
      get data_key
    rescue RecordNotFound
      raise RecordNotFound, "#{self.name} not found with id #{id.inspect}"
    end

    def get(key)
      data = Ublisherp.redis.get(key)
      if data
        deserialize(data)
      else
        raise RecordNotFound, "#{self.name} not found with key #{key}"
      end
    end

    def deserialize(data)
      ruby_data = Ublisherp::Serializer.load(data)
      raise "Only one object should be in serialized blob" if ruby_data.size != 1

      type_name = ruby_data.keys.first
      model_class =
        published_types[type_name.to_sym] || type_name.to_s.camelize.constantize

      object_attrs = ruby_data.values.first
      object_attrs.keys.grep(/_(at|on)\z/).each do |key|
        next if object_attrs[key].nil?
        object_attrs[key] = Time.parse(object_attrs[key])
      end

      model_class.belongs_to.each do |attr|
        key = object_attrs[:"#{attr}_id"]
        object_attrs[attr] = key && get(key)
      end

      model_class.has_many.each do |attr|
        object_attrs[attr] = object_attrs[:"#{attr}_ids"].map { |key|
          get key
        }
      end

      model_class.new(object_attrs)
    end

    def all(**options)
      get_sorted_set RedisKeys.key_for_all(self), **options
    end

    alias_method :to_a, :all

    def get_sorted_set(key, reverse: true, min: '-inf', max: '+inf', limit_count: 25)
      obj_keys = if reverse
                   Ublisherp.redis.zrevrangebyscore(key, max, min,
                                                    limit: [0, limit_count])
                 else
                   Ublisherp.redis.zrangebyscore(key, min, max,
                                                 limit: [0, limit_count])
                 end
      if obj_keys.present?
        Ublisherp.redis.mget(*obj_keys).tap do |objs|
          objs.map! { |obj_json| deserialize(obj_json) }
        end
      else
        []
      end
    end

    def belongs_to(*attrs)
      (@belongs_to_attrs ||= Set.new).merge attrs
    end

    def has_many(*attrs)
      (@has_many_attrs ||= Set.new).merge attrs
    end
  end

  def inspect
    "<#{self.class.name} id='#{id}'>"
  end

  def stream(name: :all, **options)
    key = RedisKeys.key_for_stream_of(self.class, name, id: id)
    self.class.get_sorted_set(key, **options)
  end


  def as_json(opts={})
    to_h
  end

  alias :attributes :to_h

  def method_missing(name, *args, &block)
    unless to_h.keys.include?(name.to_sym)
      raise NoMethodError,
        "undefined method `#{name}' for #{self.inspect}:#{self.class.name}"
    end

    super
  end
end
