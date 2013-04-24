require 'spec_helper'

describe Ublisherp::Model do
  
  def create_and_store_content_item
    ci = ContentItem.new
    ci.save
    ci.publish!
    ci
  end

  it 'returns nil if a record is not found' do
    sci = SimpleContentItem.find(19827361982736)
    expect(sci).to be_nil
  end

  it 'finds a single entity via ID' do
    ci = create_and_store_content_item
    ci.save

    sci = SimpleContentItem.find(ci.id)
    expect(sci.attributes.symbolize_keys).to eq(ci.attributes.symbolize_keys)
  end

end
