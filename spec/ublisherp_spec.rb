require 'spec_helper'

describe Ublisherp::Publishable do

  let :content_item do
    ContentItem.new
  end

  it 'Caches the publisher' do
    # pub = Ublisherp::Publisher.new content_item
    # expect(pub.publisher.class).to be Publisher
  end

end
