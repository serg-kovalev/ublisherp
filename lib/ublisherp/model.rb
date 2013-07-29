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

  class_attribute :known_fields, :known_field_defaults, instance_accessor: false

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

    def has_fields(*fields)
      options = fields.extract_options!
      fields.map! &:to_sym
      (self.known_fields ||= Set.new).merge fields

      if options[:default]
        self.known_field_defaults ||= {}
        self.known_field_defaults = self.known_field_defaults.merge(
          Hash[fields.map { |f| [f, options[:default]] }]
        )
      end
    end

    def has_stream(name, **default_options)
      define_method name do |**options|
        options.reverse_merge! default_options
        options.merge! name: name
        stream **options
      end
    end

    def scope(name, lambda = nil, &block)
      block = lambda || block
      define_singleton_method(name, &block)
    end

    def where(conditions)
      Query.new(self).where(conditions)
    end

    def find(id = nil, **conditions)
      key = key_for_id_or_index_finder(:first, id, **conditions)
      raise RecordNotFound unless key
      get key
    rescue RecordNotFound
      raise RecordNotFound, "#{self.name} not found with id #{id.inspect}"
    end

    def find_all(conditions)
      get key_for_id_or_index_finder(:all, **conditions)
    end

    def get(key)
      if key.respond_to?(:each)
        keys = Array(key)
        data = Ublisherp.redis.mget(keys)
        keys.zip(data).map do |key, serialized|
          deserialize serialized, key: key
        end
      else
        data = Ublisherp.redis.get(key)
        if data
          deserialize(data, key: key)
        else
          raise RecordNotFound, "#{self.name} not found with key #{key}"
        end
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

    def exists?(id = nil, **conditions)
      key = key_for_id_or_index_finder(:all, id, **conditions)
      return false if key.blank?
      Ublisherp.redis.exists key
    end

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

    private

    def key_for_id_or_index_finder(amount, id = nil, **conditions)
      set_cmd = {first: :srandmember, all: :smembers}.fetch(amount)

      if id.is_a?(Hash)
        conditions.reverse_merge! id
        id = nil
      elsif id
        id_key = RedisKeys.key_for(self, id: id)
      end

      if conditions.present?
        index_key = if conditions.size > 1
                      secondary_index_key_for_finder_conditions(conditions)
                    elsif conditions.size == 1
                      RedisKeys.key_for_index(self, conditions.keys.first,
                                              conditions.values.first)
                    else
                      raise "unreachable"
                    end

        if id
          if Ublisherp.redis.sismember(index_key, id_key)
            id_key
          else
            nil
          end
        else
          Ublisherp.redis.__send__(set_cmd, index_key)
        end

      elsif id
        amount == :all ? [id_key] : id_key

      else
        raise ArgumentError, "No id or conditions given"
      end
    end

    def secondary_index_key_for_finder_conditions(h)
      key = nil
      ttl = 10 * 1000

      RedisKeys.key_for_secondary_index(self, h).tap do |key|
        ttl = Ublisherp.redis.multi do
          Ublisherp.redis.pttl key
          Ublisherp.redis.expire key, -1
        end.first

        unless Ublisherp.redis.exists(key)
          index_keys = h.inject([]) { |out, c|
            out << RedisKeys.key_for_index(self, *c)
          }

          Ublisherp.redis.sinterstore(key, *index_keys)
        end
      end
    ensure
      Ublisherp.redis.pexpire key, ttl
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
    name = name.to_sym
    unless to_h.keys.include?(name) || (self.class.known_fields &&
                                        self.class.known_fields.include?(name))
      raise NoMethodError,
        "undefined method `#{name}' for #{self.inspect}:#{self.class.name}"
    end

    super_value = super
    if super_value.nil? && self.known_field_defaults.has_key?(name)
      return self.known_field_defaults
    else
      super_value
    end
  end

  def respond_to?(n)
    return true if self.class.known_fields && self.class.known_fields.include?(n.to_sym)
    super
  end
end
