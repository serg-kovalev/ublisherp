class Ublisherp::Model < OpenStruct
  include Ublisherp

  def self.published_type(name=nil)
    if name
      @published_type = name
      @@published_types ||= {}
      @@published_types[@published_type] = self
    end
    @published_type || self.name.underscore
  end

  def self.published_types
    @@published_types
  end

  def self.find(id)
    data = Ublisherp.redis.get RedisKeys.key_for(self, id: id) 
    deserialize(data) if data
  end

  def self.deserialize(data)
    ruby_data = Ublisherp::Serializer.load(data)
    raise "Only one object should be in serialized blob" if ruby_data.size != 1

    type_name = ruby_data.keys.first
    model_class =
      published_types[type_name.to_sym] || type_name.to_s.camelize.constantize

    object_attrs = ruby_data.values.first
    object_attrs.keys.grep(/_(at|on)\z/).each do |key|
      object_attrs[key] = Time.parse(object_attrs[key])
    end

    model_class.new(object_attrs)
  end

  def inspect
    "<#{self.class.name} id='#{id}'>"
  end

  def stream(name: :all, reverse: true, min: '-inf', max: '+inf', limit_count: 25)
    stream_key = RedisKeys.key_for_stream_of(self.class, name, id: id)
    method = reverse ? :zrevrangebyscore : :zrangebyscore
    obj_keys = if reverse
                 Ublisherp.redis.zrevrangebyscore(stream_key, max, min,
                                                  limit: [0, limit_count])
               else
                 Ublisherp.redis.zrangebyscore(stream_key, min, max,
                                               limit: [0, limit_count])
               end
    if obj_keys.present?
      Ublisherp.redis.mget(*obj_keys).tap do |objs|
        objs.map! { |obj_json| self.class.deserialize(obj_json) }
      end
    else
      []
    end
  end

  alias :attributes :to_h
end
