require 'spec_helper'

describe Ublisherp::Publisher do

  let :content_item do
    ContentItem.new
  end

  it 'does things' do
    expect(content_item).to be_true
    expect(Ublisherp::Publisher.new content_item ).to be_true
  end
end
