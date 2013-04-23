class Ublisherp::Publisher
  include Ublisherp

  attr_reader :publishable

  def initialize(publishable)
    @publishable = publishable
  end

  def publish!(**options)
    Ublisherp.redis.multi do
      Ublisherp.redis.set  publishable_key, publishable.to_publishable
      Ublisherp.redis.zadd RedisKeys.key_for_all(publishable), 
                           time_in_ms, 
                           publishable_key

      publish_associations
      publish_streams **options

      callback_if_present :before_publish_commit!, **options
    end
    callback_if_present :after_publish!, **options
  end

  def unpublish!(**options)
    streams = association_streams_to_unpublish

    Ublisherp.redis.multi do
      Ublisherp.redis.del  publishable_key
      Ublisherp.redis.zrem RedisKeys.key_for_all(publishable), 
                           publishable_key
      Ublisherp.redis.sadd RedisKeys.gone, publishable_key

      unpublish_associations streams

      callback_if_present :before_unpublish_commit!, **options
    end
    callback_if_present :after_unpublish!, **options
  end

  private
  
  def callback_if_present(callback, **options)
    send(callback, **options) if respond_to?(callback)
  end

  def each_publish_association
    publishable.class.publish_associations.each do |association|
      publishable.send(association).find_each(batch_size: 1000) do |instance|
        yield instance
      end
    end
  end

  def publish_associations
    each_publish_association do |assoc|
      assoc.publish!(publishable_name => publishable)
    end
  end

  def unpublish_associations(stream_keys)
    stream_keys.each do |key|
      Ublisherp.redis.zrem key, publishable_key
      Ublisherp.redis.srem RedisKeys.key_for_streams_set(publishable), key
    end
  end

  def publish_streams(**assocs)
    publishable.class.publish_streams.each do |stream|
      stream_key = RedisKeys.key_for_stream_of(publishable, stream[:name])
      stream_assocs = if stream[:associations].nil?
                        assocs.keys
                      else
                        stream[:associations] & assocs.keys
                      end
      stream_assocs.each do |sa|
        stream_obj = assocs[sa]
        next if (stream[:if] && !stream[:if].call(stream_obj)) ||
                (stream[:unless] && stream[:unless].call(stream_obj))

        Ublisherp.redis.zadd stream_key, 
                             time_in_ms,
                             RedisKeys.key_for(stream_obj)

        Ublisherp.redis.sadd RedisKeys.key_for_streams_set(stream_obj),
                             stream_key
      end
    end
  end

  def association_streams_to_unpublish
    streams_set_key = RedisKeys.key_for_streams_set publishable
    Ublisherp.redis.smembers(streams_set_key)
  end

  def publishable_name
    publishable.class.name.underscore.to_sym
  end

  def publishable_key
    RedisKeys.key_for(publishable)
  end

  def time_in_ms
    # Note that, this will only work in Ruby, as MySQL is not ms precise
    (Time.now.to_f * 1000).to_i
  end

end

