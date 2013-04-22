class Ublisherp::Publisher
  include Ublisherp

  attr_reader :publishable

  def initialize(publishable)
    @publishable = publishable
  end

  def publish!(**options)
    Ublisherp.redis.multi do
      Ublisherp.redis.set publishable_key, publishable.to_publishable

      publishable_name = publishable.class.name.underscore.to_sym
      publishable.class.publish_associations.each do |assoc|
        Array(publishable.send(assoc)).each do |a|
          a.publish!(publishable_name => publishable)
        end
      end

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

  def publishable_key
    @publishable_key ||= RedisKeys.key_for(publishable)
  end

end
