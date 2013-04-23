module Ublisherp::RedisKeys

  def self.key_for(obj)
    "#{obj.class.name}:#{obj.id}"
  end

  def self.key_for_all(obj)
    "#{obj.class.name}:all"
  end

  def self.key_for_stream_of(obj, name)
    "#{key_for(obj)}:streams:#{name}"
  end

  def self.key_for_streams_set(obj)
    "#{key_for(obj)}:in_streams"
  end

  def self.gone
    "gone"
  end

end
