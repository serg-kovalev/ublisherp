require 'spec_helper'

describe Ublisherp do

  let :content_item do
    ContentItem.new
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
      expect($redis.get()).to be_nil
    end
  end
end

