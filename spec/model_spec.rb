require 'spec_helper'

describe Ublisherp::Model do
  
  def create_and_store_content_item(**options)
    ci = ContentItem.new(**options)
    ci.save!
    ci.publish!
    ci
  end

  it 'raises an exception if a record is not found' do
    expect {
      SimpleContentItem.find(19827361982736)
    }.to raise_error(Ublisherp::Model::RecordNotFound)
  end

  it "responds to exists? properly" do
    ci = ContentItem.new(slug: 'cheese')
    ci.save!
    id = ci.id
    expect(SimpleContentItem.exists?(id)).to be_false
    expect(SimpleContentItem.exists?(slug: 'cheese')).to be_false

    ci.publish!

    expect(SimpleContentItem.exists?(id)).to be_true
    expect(SimpleContentItem.exists?(slug: 'cheese')).to be_true
  end

  it 'finds a single entity via ID' do
    ci = create_and_store_content_item

    sci = SimpleContentItem.find(ci.id)
    expect(sci.attributes.symbolize_keys.merge(type: nil)).to \
      eq(ci.attributes.symbolize_keys.merge(section: nil, tags: [],
                                            tags_ids: [], key: sci.key,
                                            score: nil))
  end

  it 'returns a stream of objects' do
    ci = create_and_store_content_item(stream_score: Time.now - 60)
    ci2 = create_and_store_content_item(stream_score: Time.now)
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

    stream_arr = st.stream
    expect(stream_arr).to eq([sci2, sci])
    expect(stream_arr.has_more?).to be_false

    orig_default_limit_count = st.class.default_limit_count
    st.class.default_limit_count = 1
    stream_arr = st.stream
    expect(stream_arr).to eq([sci2])
    expect(stream_arr.has_more?).to be_true
    st.class.default_limit_count = orig_default_limit_count

    expect(st.stream(reverse: false)).to eq([sci, sci2])
  end

  it 'returns a stream of objects from a helper defined with has_stream' do
    sec = Section.new(name: "Cheese")
    ci = create_and_store_content_item(stream_score: Time.now - 60, section: sec)
    ci2 = create_and_store_content_item(stream_score: Time.now, section: sec)

    ssec = SimpleSection.find(sec.id)
    sci1 = SimpleContentItem.find(ci.id)
    sci2 = SimpleContentItem.find(ci2.id)

    expect(ssec.content_items).to eq([sci2])
    expect(ssec.content_items(page: 2)).to eq([sci1])
    expect(ssec.content_items(reverse: false, limit_count: 2)).
      to eq([sci1, sci2])
  end

  it 'pages through a stream' do
    stream_time = Time.now.change(ms: 0).to_i
    cis = []
    tag = Tag.create!(name: 'cheese')
    dupe_score = nil
    dupe_ids = []
    dupe_keys = []

    50.times do |n|
      ci = create_and_store_content_item(stream_score: stream_time)
      ci.tags << tag
      ci.save!
      ci.publish!
      cis << ci

      if n == 10 || n == 11
        dupe_ids << ci.id
        dupe_keys << Ublisherp::RedisKeys.key_for(ci)
      end

      if n == 10
        dupe_score = stream_time.to_i
      else
        stream_time -= 2
      end
    end

    scis = cis.map { |ci| SimpleContentItem.find(ci.id) }
    st = SimpleTag.find(tag.id)

    stream_arr = st.stream
    expect(stream_arr).to match_array(scis[0..24])
    expect(stream_arr.has_more?).to be_true
    stream_arr = st.stream(page: 1)
    expect(stream_arr).to match_array(scis[0..24])
    expect(stream_arr.has_more?).to be_true
    stream_arr = st.stream(page: 2)
    expect(stream_arr).to match_array(scis[25..50])
    expect(stream_arr.has_more?).to be_false
    stream_arr = st.stream(page: 3)
    expect(stream_arr).to match_array([])
    expect(stream_arr.has_more?).to be_false

    first_sci = scis.detect { |sci| sci.id == dupe_ids.last }
    expect(first_sci).to_not be_nil
    idx = scis.index(first_sci)

    expected_scis = scis[idx..(idx + 24)]
    expect(expected_scis.size).to eq(25)

    expect(st.stream(max: dupe_score, last_key: dupe_keys.first)).to \
      match_array(expected_scis)
  end

  it "doesn't crash when it has to remove the last key and there are no more objects to retrieve" do
    stream_time = Time.now.change(ms: 0).to_i
    cis = []
    tag = Tag.create!(name: 'cheese')

    4.times do
      ci = create_and_store_content_item(stream_score: stream_time)
      ci.tags << tag
      ci.save!
      ci.publish!
    end

    st = SimpleTag.find(tag.id)

    expect(st.stream(page: 5, limit_count: 1)).to eq([])
  end

  it 'returns all objects published' do
    ci = create_and_store_content_item(stream_score: Time.now - 60)
    ci2 = create_and_store_content_item(stream_score: Time.now)

    sci = SimpleContentItem.find(ci.id)
    sci2 = SimpleContentItem.find(ci2.id)

    expect(SimpleContentItem.all).to eq([sci2, sci])
    expect(SimpleContentItem.all(reverse: false)).to eq([sci, sci2])
  end

  it 'can retrieve a content item by indexed attribute' do
    ci = create_and_store_content_item(slug: 'a-crazy-badger')
    sci = SimpleContentItem.find(ci.id)

    expect(SimpleContentItem.find(slug: 'a-crazy-badger')).to eq(sci)

    expect {
      SimpleContentItem.find(slug: 'qwer')
    }.to raise_error(Ublisherp::Model::RecordNotFound)
  end

  it "can retrieve a content item using two indexes" do
    ci_stuff = create_and_store_content_item(slug: 'stuff', visible: true)
    ci_things = create_and_store_content_item(slug: 'things', visible: false)

    sci_stuff = SimpleContentItem.find(ci_stuff.id)
    sci_things = SimpleContentItem.find(ci_things.id)

    expect(SimpleContentItem.exists?(slug: 'stuff', visible: true)).to be_true
    expect(SimpleContentItem.find(slug: 'stuff', visible: true)).to eq(sci_stuff)
    expect(SimpleContentItem.exists?(slug: 'things', visible: false)).to be_true
    expect(SimpleContentItem.find(slug: 'things', visible: false)).to eq(sci_things)

    expect(SimpleContentItem.exists?(slug: 'stuff', visible: false)).to be_false
    expect {
      SimpleContentItem.find(slug: 'stuff', visible: false)
    }.to raise_error(Ublisherp::Model::RecordNotFound)

    expect(SimpleContentItem.exists?(slug: 'things', visible: true)).to be_false
    expect {
      SimpleContentItem.find(slug: 'things', visible: true)
    }.to raise_error(Ublisherp::Model::RecordNotFound)
  end

  it 'raises an error for unknown methods' do
    ci = create_and_store_content_item
    sci = SimpleContentItem.find(ci.id)

    expect {
      sci.asdfasdfwqerqwer
    }.to raise_error(NoMethodError)
  end

  it "doesn't claim it responds to methods it doesn't have a hash key for" do
    ci = create_and_store_content_item
    sci = SimpleContentItem.find(ci.id)

    expect(sci.respond_to?(:qsdfasdfasdf)).to be_false
  end

  it "claims it responds to methods that are part of the struct" do
    ci = create_and_store_content_item
    sci = SimpleContentItem.find(ci.id)

    expect(sci.respond_to?(:slug)).to be_true
  end

  it "claims it responds to methods that are defined, but not part of the struct" do
    ci = create_and_store_content_item
    sci = SimpleContentItem.find(ci.id)

    expect(sci.respond_to?(:stream)).to be_true
  end

  it "is associated with another Model object" do
    section_name = "Blah"
    tag_names = ['cheese', 'badgers']
    ci = create_and_store_content_item(section:
                                         Section.create!(name: section_name),
                                       tags: tag_names.map { |n|
                                         Tag.create! name: n
                                       })
    sci = SimpleContentItem.find(ci.id)

    expect(sci.section).to be_a(Ublisherp::Model)
    expect(sci.section.name).to eq(section_name)
    expect(sci.tags.map(&:name)).to match_array(tag_names)
  end
end
