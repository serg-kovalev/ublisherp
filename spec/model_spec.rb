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

    sci = SimpleContentItem.find(ci.id)
    expect(sci.attributes.symbolize_keys).to eq(ci.attributes.symbolize_keys)
  end

  it 'returns a stream of objects' do
    ci = create_and_store_content_item
    ci2 = create_and_store_content_item
    tag = Tag.new(name: 'cheese')
    tag.save
    [ci, ci2].each do |c|
      c.tags << tag
      c.save
      c.publish!
    end

    sci = SimpleContentItem.find(ci.id)
    sci2 = SimpleContentItem.find(ci2.id)
    st = SimpleTag.find(tag.id)

    expect(st.stream).to eq([sci2, sci])
    expect(st.stream(reverse: false)).to eq([sci, sci2])
  end

  it 'returns all objects published' do
    ci = create_and_store_content_item
    ci2 = create_and_store_content_item

    sci = SimpleContentItem.find(ci.id)
    sci2 = SimpleContentItem.find(ci2.id)

    expect(SimpleContentItem.all).to eq([sci2, sci])
    expect(SimpleContentItem.all(reverse: false)).to eq([sci, sci2])
  end
end
