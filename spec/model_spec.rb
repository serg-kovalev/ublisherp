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

  it 'raises an exception with the conditions in the message' do
    ci = create_and_store_content_item
    slug = 'AASDFASDFAWQERQWER'

    begin
      SimpleContentItem.find(slug: slug)
    rescue Ublisherp::Model::RecordNotFound => e
      expect(e.message).to include(slug)
    else
      fail "no exception raised"
    end
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

    # page should be ignored when given a last_key
    expect(st.stream(max: dupe_score, last_key: dupe_keys.first, page: 2)).to \
      match_array(expected_scis)
  end

  it "returns a type stream of objects" do
    ci = create_and_store_content_item(stream_score: Time.now - 60)
    ci2 = create_and_store_content_item(stream_score: Time.now, visible: false)
    [ci, ci2].each &:publish!

    sci = SimpleContentItem.find(ci.id)
    sci2 = SimpleContentItem.find(ci2.id)

    stream_arr = SimpleContentItem.type_stream
    expect(stream_arr).to eq([sci2, sci])
    expect(stream_arr.has_more?).to be_false

    stream_arr = SimpleContentItem.type_stream(reverse: false)
    expect(stream_arr).to eq([sci, sci2])
    expect(stream_arr.has_more?).to be_false

    expect(SimpleContentItem.visible).to eq([sci])
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

  it 'returns first and last objects published' do
    ci = create_and_store_content_item(stream_score: Time.now - 60)
    ci2 = create_and_store_content_item(stream_score: Time.now)

    sci = SimpleContentItem.find(ci.id)
    sci2 = SimpleContentItem.find(ci2.id)

    expect(SimpleContentItem.first).to eq(sci)
    expect(SimpleContentItem.last).to eq(sci2)
  end

  it 'can retrieve a content item by indexed attribute' do
    ci = create_and_store_content_item(slug: 'a-crazy-badger')
    sci = SimpleContentItem.find(ci.id)

    expect(SimpleContentItem.find(slug: 'a-crazy-badger')).to eq(sci)

    expect {
      SimpleContentItem.find(slug: 'qwer')
    }.to raise_error(Ublisherp::Model::RecordNotFound)
  end

  def create_multi_index_items
    @ci_stuff = create_and_store_content_item(slug: 'stuff', visible: true)
    @ci_cheese = create_and_store_content_item(slug: 'cheese', visible: true)
    @ci_things = create_and_store_content_item(slug: 'things', visible: false)

    @sci_stuff = SimpleContentItem.find(@ci_stuff.id)
    @sci_cheese = SimpleContentItem.find(@ci_cheese.id)
    @sci_things = SimpleContentItem.find(@ci_things.id)
  end

  it "can have scopes defined" do
    create_multi_index_items

    expect(SimpleContentItem.visible).to match_array([@sci_stuff, @sci_cheese])
    expect(SimpleContentItem.visible.find(@sci_stuff.id)).to eq(@sci_stuff)
    expect(-> {
      SimpleContentItem.visible.find(@sci_things.id)
    }).to raise_error(Ublisherp::Model::RecordNotFound)
  end

  it "can retrieve a content item using two indexes" do
    create_multi_index_items

    expect(SimpleContentItem.exists?(slug: 'stuff', visible: true)).to be_true
    expect(SimpleContentItem.find(slug: 'stuff', visible: true)).to eq(@sci_stuff)
    expect(SimpleContentItem.exists?(slug: 'things', visible: false)).to be_true
    expect(SimpleContentItem.find(slug: 'things', visible: false)).
      to eq(@sci_things)

    expect(SimpleContentItem.where(visible: true)).
      to match_array([@sci_stuff, @sci_cheese])
    expect(SimpleContentItem.where(visible: false)).to match_array([@sci_things])
    expect(SimpleContentItem.where(slug: 'stuff')).to match_array([@sci_stuff])
    expect(SimpleContentItem.where(slug: 'things')).to match_array([@sci_things])
    expect(SimpleContentItem.where(slug: 'stuff').where(visible: true)).
      to match_array([@sci_stuff])
    expect(SimpleContentItem.where(slug: 'things').where(visible: false)).
      to match_array([@sci_things])
  end

  it "can find a record with given conditions" do
    create_multi_index_items

    expect(SimpleContentItem.where(visible: true).find(@ci_stuff.id)).
      to eq(@sci_stuff)
    expect(SimpleContentItem.where(visible: true).find(slug: 'stuff')).
      to eq(@sci_stuff)
    expect(-> {
      SimpleContentItem.where(visible: false).find(@ci_stuff.id)
    }).to raise_error(Ublisherp::Model::RecordNotFound)
    expect(-> {
      SimpleContentItem.where(visible: false).find(slug: 'stuff')
    }).to raise_error(Ublisherp::Model::RecordNotFound)

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

  it "has known fields that will not raise an error when requested, even if they don't exist" do
    ci = create_and_store_content_item
    sci = SimpleContentItem.find(ci.id)

    expect(sci.cheese_breed).to be_nil
  end

  it "claims it responds to known fields" do
    ci = create_and_store_content_item
    sci = SimpleContentItem.find(ci.id)

    expect(sci.respond_to?(:cheese_breed)).to be_true
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

  it "can have a default value for a field that isn't nil" do
    ci = create_and_store_content_item
    sci = SimpleContentItem.find(ci.id)

    expect(sci.enabled).to be_true
  end

  it "has a default field on a model without any defaults" do
    section = Section.create!(name: "Cheese")
    section.publish!
    ssec = SimpleSection.find(section.id)

    expect(ssec.enabled).to be_nil
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

  it "doesn't crash if .get is called with an empty array" do
    expect(SimpleContentItem.get([])).to eq([])
  end
end
