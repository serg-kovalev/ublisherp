require 'set'

require 'active_model/naming'
require 'active_model/conversion'

class Ublisherp::Model < OpenStruct
  include Ublisherp

  extend ActiveModel::Naming
  include ActiveModel::Conversion

  class RecordNotFound < StandardError; end

  class_attribute :default_limit_count
  self.default_limit_count = 25

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

    def has_stream(name, **default_options)
      define_method name do |**options|
        options.reverse_merge! default_options
        options.merge! name: name
        stream **options
      end
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
        deserialize(data, key: key)
      else
        raise RecordNotFound, "#{self.name} not found with key #{key}"
      end
    end

    def deserialize(data, **extra)
      raise ArgumentError, "no key supplied" unless extra[:key]
      extra[:score] ||= nil

      ruby_data = Ublisherp::Serializer.load(data)
      raise "Only one object should be in serialized blob" if ruby_data.size != 1

      type_name = ruby_data.keys.first
      model_class =
        published_types[type_name.to_sym] || type_name.to_s.camelize.constantize

      object_attrs = ruby_data.values.first
      object_attrs.keys.grep(/_(at|on)\z/).each do |key|
        next if object_attrs[key].nil?
        object_attrs[key] = Time.parse(object_attrs[key]).in_time_zone
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

      object_attrs.merge! extra
      model_class.new(object_attrs)
    end

    def all(**options)
      get_sorted_set RedisKeys.key_for_all(self), **options
    end

    alias_method :to_a, :all

    def get_sorted_set(key, reverse: true, min: '-inf', max: '+inf',
                       limit_count: nil, page: nil, last_key: nil)

      limit_count ||= default_limit_count
      adj_limit_count = limit_count
      last_page_count = adj_limit_count
      adj_limit_count += 1 # for last page detection
      adj_limit_count += 1 if last_key
 
      min_limit = if page
                    (page - 1) * limit_count
                  else
                    0
                  end
      out = Ublisherp::Collection.new

      obj_keys = if reverse
                   Ublisherp.redis.zrevrangebyscore(key, max, min,
                                                    limit: [min_limit,
                                                            adj_limit_count],
                                                    withscores: true)
                 else
                   Ublisherp.redis.zrangebyscore(key, min, max,
                                                 limit: [min_limit,
                                                         adj_limit_count],
                                                 withscores: true)
                 end

      if obj_keys.present?
        scores = Hash[obj_keys]
        obj_keys = scores.keys
        obj_keys.delete(last_key) if last_key

        if obj_keys.size > last_page_count
          out.has_more = true
          obj_keys.slice! limit_count..-1
        end

        Ublisherp.redis.mget(*obj_keys).each_with_index do |obj_json, i|
          key = obj_keys[i]
          out << deserialize(obj_json, key: key, score: scores[key])
        end
      end

      out
    end

    def belongs_to(*attrs)
      (@belongs_to_attrs ||= Set.new).merge attrs
    end

    def has_many(*attrs)
      (@has_many_attrs ||= Set.new).merge attrs
    end
  end

  def ==(other)
    self.class == other.class && self.id == other.id
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
