require 'spec_helper'

describe Ublisherp do

  let :content_item do
    ContentItem.new
  end

  let :tag do
    Tag.new
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

    it 'sets something in a redis key for the content item' do
      expect($redis.get(Ublisherp::RedisKeys.key_for(content_item))).to be_nil

      content_item.save
      content_item.publish!

      expect($redis.get(Ublisherp::RedisKeys.key_for(content_item))).to eq(
        content_item.to_publishable)
    end

    it 'removes an item from redis when it is unpublished' do
      content_item.save
      content_item.publish!
      content_item.unpublish!

      expect($redis.get(Ublisherp::RedisKeys.key_for(content_item))).to be_nil
    end

    it 'adds an unpublished key to the gone_keys set' do
      content_item.save
      content_item.publish!
      content_item.unpublish!

      expect($redis.sismember(
        Ublisherp::RedisKeys.gone_keys,
        Ublisherp::RedisKeys.key_for(content_item))).to be_true
    end

    it 'runs callbacks on publish' do
      content_item.publisher.should_receive(:before_publish_commit!)
      content_item.publish!
    end

    it 'runs callbacks on unpublish' do
      content_item.publisher.should_receive(:before_unpublish_commit!)
      content_item.unpublish!
    end

    it 'also publishes associated objects declared with publishes_associations' do
      tag.save
      content_item.tags << tag
      content_item.publish!

      expect($redis.get(Ublisherp::RedisKeys.key_for(tag))).to_not be_nil
    end
  end
end

