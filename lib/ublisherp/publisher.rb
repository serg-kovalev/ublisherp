class Ublisherp::Publisher
  include Ublisherp

  attr_reader :publishable

  def initialize(publishable)
    @publishable = publishable
  end

  def publish!(**options)
    return if publishable.run_hook(:before_publish, options) == false

    Ublisherp.redis.multi do
      Ublisherp.redis.set publishable_key,
        Serializer.dump(publishable.as_publishable_with_associations)
      Ublisherp.redis.zadd RedisKeys.key_for_all(publishable),
                           score_for(publishable), 
                           publishable_key
    end

    publish_associations
    publish_streams **options
    publish_indexes

    publishable.run_hook :after_publish, options
  end

  def unpublish!(**options)
    return if publishable.run_hook(:before_unpublish, options) == false

    streams = association_streams_to_unpublish
    indexes = publishable_current_indexes

    Ublisherp.redis.multi do
      Ublisherp.redis.del  publishable_key
      Ublisherp.redis.zrem RedisKeys.key_for_all(publishable), 
                           publishable_key
      Ublisherp.redis.sadd RedisKeys.gone, publishable_key

      unpublish_streams streams
      unpublish_indexes indexes

      publishable.run_hook :before_unpublish_commit, options
    end
    publishable.run_hook :after_unpublish, options
  end


  private
  
  def publish_associations
    publishable.publish_association_attrs.each do |assoc_name|
      published_keys = Set.new(Ublisherp.redis.smembers(
        RedisKeys.key_for_associations(publishable, assoc_name)))

      inner_block = proc do |instance|
        assoc_key = RedisKeys.key_for(instance)

        published_keys.delete assoc_key
        instance.publisher.publish!(publishable_name => publishable)
        Ublisherp.redis.sadd(RedisKeys.key_for_associations(publishable,
                                                            assoc_name),
                                                            RedisKeys.key_for(instance))
      end

      assoc_objs = publishable.__send__(assoc_name)
      if assoc_objs.respond_to?(:find_each)
        assoc_objs.find_each(batch_size: 1000, &inner_block)
      else
        Array(assoc_objs).each(&inner_block)
      end

      # The keys left should be removed
      if published_keys.present?
        unpublish_from_streams_of_associations published_keys
        Ublisherp.redis.srem(RedisKeys.key_for_associations(publishable,
                                                            assoc_name),
                             *published_keys.to_a)
      end
    end
  end

  def unpublish_streams(stream_keys)
    stream_keys.each do |key|
      Ublisherp.redis.zrem key, publishable_key
      Ublisherp.redis.srem RedisKeys.key_for_streams_set(publishable), key
    end
  end

  def publish_streams(**assocs)
    publishable.publish_stream_specs.each do |stream|
      Ublisherp.redis.multi do
        stream_key = RedisKeys.key_for_stream_of(publishable, stream[:name])
        stream_assocs = if stream[:associations].nil?
                          assocs.keys
                        else
                          stream[:associations] & assocs.keys
                        end
        stream_assocs.each do |sa|
          stream_obj = assocs[sa]
          next if stream_obj.run_hook(:before_add_to_stream, publishable,
                                      stream[:name]) == false
          next if (stream[:if] && !stream[:if].call(stream_obj)) ||
            (stream[:unless] && stream[:unless].call(stream_obj))

          stream_classes = Array(stream[:class])
          if stream_classes.present?
            next unless stream_classes.any? { |cls| cls === stream_obj }
          end

          Ublisherp.redis.zadd stream_key, 
                               score_for(stream_obj),
                               RedisKeys.key_for(stream_obj)

          Ublisherp.redis.sadd RedisKeys.key_for_streams_set(stream_obj),
                               stream_key

          stream_obj.run_hook :after_add_to_stream, publishable, stream[:name]
        end

        Ublisherp.redis.sadd RedisKeys.key_for_has_streams(publishable),
                             stream_key
      end
    end
  end

  def unpublish_from_streams_of_associations(keys)
    return if keys.blank?

    keys.each do |assoc_key|
      stream_keys = Ublisherp.redis.smembers(RedisKeys.key_for_has_streams(assoc_key))

      Ublisherp.redis.multi do
        stream_keys.each do |stream_key|
          Ublisherp.redis.zrem stream_key, publishable_key
        end
      end
    end
  end

  def publishable_current_indexes
    Ublisherp.redis.smembers(RedisKeys.key_for_in_indexes(publishable))
  end

  def publish_indexes
    current_indexes = publishable_current_indexes

    Ublisherp.redis.multi do
      unpublish_indexes current_indexes
      publishable.publish_index_attrs.each do |index_attr|
        index_key = RedisKeys.key_for_index(publishable, index_attr)
        Ublisherp.redis.sadd index_key, publishable_key
        Ublisherp.redis.sadd RedisKeys.key_for_in_indexes(publishable), index_key
      end
    end
  end

  def unpublish_indexes(indexes)
    indexes.each do |i|
      Ublisherp.redis.srem i, publishable_key
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

  def score_for(obj)
    if obj.respond_to?(:ublisherp_stream_score)
      obj.ublisherp_stream_score.to_f
    else
      Time.now.to_f
    end
  end

end

