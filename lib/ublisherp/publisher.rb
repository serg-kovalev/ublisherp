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

      callback_if_present :before_publish_commit!, **options
    end
    callback_if_present :after_publish!, **options
  end

  def unpublish!(**options)
    Ublisherp.redis.multi do
      Ublisherp.redis.del  publishable_key
      Ublisherp.redis.zrem RedisKeys.key_for_all(publishable), 
                           publishable_key
      Ublisherp.redis.sadd RedisKeys.gone, publishable_key

      callback_if_present :before_unpublish_commit!, **options
    end
    callback_if_present :after_unpublish!, **options
  end

  private
  
  def callback_if_present(callback, **options)
    send(callback, **options) if respond_to?(callback)
  end

  def publish_associations
    publishable.class.publish_associations.each do |association|
      publishable.send(association).find_each(batch_size: 1000) do |instance|
        instance.publish!(publishable_name => publishable)
      end
    end
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

