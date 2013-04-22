module Ublisherp::RedisKeys

  def self.key_for(obj)
    "#{obj.class.name}:#{obj.id}"
  end

  def self.key_for_all(obj)
    "#{obj.class.name}:all"
  end

  def self.key_for_stream_of(obj)
    "#{key_for(obj)}:stream"
  end

  def self.gone
    "gone"
  end

end
