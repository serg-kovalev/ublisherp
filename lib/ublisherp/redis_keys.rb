module Ublisherp::RedisKeys

  def self.key_for(obj, id: nil)
    return obj if obj.is_a?(String)

    if id
      klass = obj.published_type
    else # We are working out the key from an instance of an object
      raise(ArgumentError, "Object doesn't have an id yet") if obj.id.blank?
      id = obj.id
      klass = obj.class.name.underscore
    end

    "#{klass}:#{id}"
  end

  def self.key_for_all(obj)
    obj = obj.class unless Class === obj
    "#{obj.published_type}:all"
  end

  def self.key_for_associations(obj, assoc)
    "#{key_for(obj)}:associations:#{assoc}"
  end

  def self.key_for_has_streams(obj)
    "#{key_for(obj)}:has_streams"
  end

  def self.key_for_stream_of(obj, name, id: nil)
    "#{key_for(obj, id: id)}:streams:#{name}"
  end

  def self.key_for_streams_set(obj)
    "#{key_for(obj)}:in_streams"
  end

  def self.gone
    "gone"
  end

end
