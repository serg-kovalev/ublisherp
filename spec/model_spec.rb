require 'spec_helper'

describe Ublisherp::Model do
  
  def create_and_store_content_item
    ci = ContentItem.new
    ci.save
    ci.publish!
    ci
  end

  it 'finds a single entity via ID' do
    ci = create_and_store_content_item

    sci = SimpleContentItem.find(ci.id)
    expect(sci.id).to eq(ci.id)
  end

end
