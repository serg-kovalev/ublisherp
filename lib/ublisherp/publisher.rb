class Ublisherp::Publisher
  include Ublisherp

  attr_reader :publishable

  def initialize(publishable)
    @publishable = publishable
  end

  def publish!(**options)
    Ublisherp.redis.multi do
      Ublisherp.redis.set publishable_key, publishable.to_publishable

      publish_associations

      if respond_to?(:before_publish_commit!)
        before_publish_commit!(**options)
      end
    end
  end

  def unpublish!(**options)
    Ublisherp.redis.multi do
      Ublisherp.redis.sadd RedisKeys.gone_keys, publishable_key
      Ublisherp.redis.del publishable_key

      if respond_to?(:before_unpublish_commit!)
        before_unpublish_commit!(**options)
      end
    end
  end

  private

  def publish_associations
    # binding.pry
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

end
