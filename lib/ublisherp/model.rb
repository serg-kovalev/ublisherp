class Ublisherp::Model < OpenStruct
  include Ublisherp

  def self.model_name(name=nil)
    @@model_name = name if name
    @@model_name || self.name
  end
  
  def self.find(id)
    data = Ublisherp.redis.get RedisKeys.key_for(self, id: id) 
    deserialize(data) if data
  end

  def self.deserialize(data)
    ruby_data = Ublisherp::Serializer.load(data)
    object_attrs = ruby_data[self.model_name.underscore.to_sym]
    self.new(object_attrs)
  end

  def inspect
    "<#{self.class.name} id='#{id}'>"
  end
end
