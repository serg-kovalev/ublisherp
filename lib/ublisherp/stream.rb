require 'ublisherp/stream_spec'

module Ublisherp
  class Stream < StreamSpec
    undef :for_publishable

    def key
      @key ||= Ublisherp::RedisKeys.key_for_stream_of(self.publishable,
                                                      self.name)
    end

    def first_stream_add?(stream_obj)
      !Ublisherp.redis.zscore(key, Ublisherp::RedisKeys.key_for(stream_obj))
    end
  end

  class TypeStream < Stream
    def key
      @key ||= Ublisherp::RedisKeys.key_for_type_stream_of(self.publishable,
                                                           self.name)
    end
  end
end
