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

  alias :attributes :to_h
end
