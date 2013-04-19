require 'spec_helper'

describe Ublisherp::Publishable do

  let :content_item do
    ContentItem.new
  end

  it 'Caches the publisher' do
    pub = content_item.publisher.class
    expect(pub).to be Ublisherp::Publisher
  end

end
