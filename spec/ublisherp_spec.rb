require 'spec_helper'

describe Ublisherp do

  let :section do
    Section.create!(name: "A section")
  end

  let :content_item do
    ContentItem.create!(section: section)
  end

  let :tag do
    Tag.create!(name: "Cheese")
  end

  describe Ublisherp::Publishable do
    it 'caches the publisher' do
      pub = content_item.publisher.class
      expect(pub).to be Ublisherp::Publisher
    end

    it 'delegates #publish! to publisher' do
      content_item.publisher.should_receive(:publish!).once
      content_item.publish!
    end
  end

  describe Ublisherp::Publisher do

    let :publisher do
      content_item.publisher
    end

    def all_key_score
      $redis.zscore Ublisherp::RedisKeys.key_for_all(content_item),
                    Ublisherp::RedisKeys.key_for(content_item)
    end

    it 'sets something in a redis key for the content item' do
      expect($redis.get(Ublisherp::RedisKeys.key_for(content_item))).to be_nil

      content_item.publish!

      expect(
        $redis.get(Ublisherp::RedisKeys.key_for(content_item))).to eq(
        Ublisherp::Serializer.dump(content_item)
      )
    end

    it 'adds something to the classes all sorted set when published' do
      expect(all_key_score).to be_nil

      content_item.publish!
      
      expect(all_key_score).to_not be_nil
    end

    it 'removes an item from redis when it is unpublished' do
      content_item.publish!
      content_item.unpublish!

      expect($redis.get(Ublisherp::RedisKeys.key_for(content_item))).to be_nil
    end

    it 'removes something to the classes all sorted set when unpublished' do
      content_item.publish!
      content_item.unpublish!

      expect(all_key_score).to be_nil
    end

    it 'adds an unpublished key to the gone_keys set' do
      content_item.publish!
      content_item.unpublish!

      expect($redis.sismember(
        Ublisherp::RedisKeys.gone,
        Ublisherp::RedisKeys.key_for(content_item))).to be_true
    end

    it 'runs after callbacks on publish' do
      content_item.publisher.should_receive(:after_publish!)
      content_item.publish!
    end

    it 'runs before callbacks on unpublish' do
      content_item.publisher.should_receive(:before_unpublish_commit!)
      content_item.unpublish!
    end

    it 'runs after callbacks on unpublish' do
      content_item.publisher.should_receive(:after_unpublish!)
      content_item.unpublish!
    end

    it 'also publishes associated objects 
        declared with publishes_associations' do
      content_item.tags << tag
      content_item.save!
      content_item.publish!

      expect($redis.get(Ublisherp::RedisKeys.key_for(tag))).to_not be_nil
      expect($redis.get(Ublisherp::RedisKeys.key_for(section))).to_not be_nil
    end

    it 'publishes a content item to a tag stream' do
      content_item.tags << tag
      content_item.save!
      content_item.publish!

      wrong_stream_key = Ublisherp::RedisKeys.key_for_stream_of(content_item,
                                                                :all)
      content_key = Ublisherp::RedisKeys.key_for(content_item)

      [tag, section].each do |o|
        stream_key = Ublisherp::RedisKeys.key_for_stream_of(o, :all)

        expect($redis.zrange(stream_key, 0, -1)).to eq([content_key])
        expect($redis.zcard(wrong_stream_key)).to eq(0)
      end
    end

    it 'adds each stream to the "in_streams" set for each item' do
      content_item.tags << tag
      content_item.save!

      stream_set_key = Ublisherp::RedisKeys.key_for_streams_set(content_item)

      expect($redis.scard(stream_set_key)).to eq(0)

      content_item.publish!

      stream_keys = [section, tag].map { |o|
        Ublisherp::RedisKeys.key_for_stream_of(o, :all)
      } << Ublisherp::RedisKeys.key_for_stream_of(section, :content_items)

      expect($redis.smembers(stream_set_key)).to match_array(stream_keys)
    end

    it 'unpublishes a content item from a tag stream 
        and its "in streams" key' do
      content_item.tags << tag
      content_item.save!
      content_item.publish!
      content_item.unpublish!

      content_key = Ublisherp::RedisKeys.key_for(content_item)
      stream_set_key = Ublisherp::RedisKeys.key_for_streams_set(content_item)
      
      [tag, section].each do |o|
        stream_key = Ublisherp::RedisKeys.key_for_stream_of(tag, :all)
        expect($redis.zrange(stream_key, 0, -1)).to eq([])
        expect($redis.scard(stream_set_key)).to eq(0)
      end
    end

    it 'tracks associations and unpublishes itself from old ones' do

      t1 = Tag.new name: 'Tag 1'
      t2 = Tag.new name: 'Tag 2'

      content_item.tags << t1
      content_item.tags << t2
      content_item.save!

      content_item.publish!

      t1_stream_key =  Ublisherp::RedisKeys.key_for_stream_of(t1, :all)
      t2_stream_key = Ublisherp::RedisKeys.key_for_stream_of(t2, :all)
      section_stream_key = Ublisherp::RedisKeys.key_for_stream_of(section, :all)

      expect($redis.zcount(t1_stream_key,  '-inf', '+inf')).to eq(1)
      expect($redis.zcount(t2_stream_key, '-inf', '+inf')).to eq(1)
      expect($redis.zcount(section_stream_key, '-inf', '+inf')).to eq(1)

      content_item.tags = []
      content_item.tags << t2
      content_item.section = nil
      content_item.save!
      content_item.publish!

      expect($redis.zcount(t1_stream_key,  '-inf', '+inf')).to eq(0)
      expect($redis.zcount(t2_stream_key, '-inf', '+inf')).to eq(1)
      expect($redis.zcount(section_stream_key, '-inf', '+inf')).to eq(0)
    end

    it 'uses the given stream score if defined' do
      content_item.tags << tag
      content_item.save!

      score_should = content_item.ublisherp_stream_score

      content_item.publish!

      stream_key = Ublisherp::RedisKeys.key_for_stream_of(tag, :all)
      stream = $redis.zrangebyscore(stream_key, '-inf', '+inf', withscores: true)

      expect(stream.first.last).to eq(score_should)
    end

  end
end

