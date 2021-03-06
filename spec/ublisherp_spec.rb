require 'spec_helper'

describe Ublisherp do

  let :section do
    Section.create!(name: "A section")
  end

  let :content_item do
    ContentItem.create!(section: section)
  end

  let :inherited_content_item do
    InheritedContentItem.create!(section: section)
  end

  let :tag do
    Tag.create!(name: "Cheese")
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

    def all_key_score
      $redis.zscore Ublisherp::RedisKeys.key_for_all(content_item),
                    Ublisherp::RedisKeys.key_for(content_item)
    end

    it 'sets something in a redis key for the content item' do
      expect($redis.get(Ublisherp::RedisKeys.key_for(content_item))).to be_nil

      content_item.publish!

      expect(
        $redis.get(Ublisherp::RedisKeys.key_for(content_item))).to eq(
        Ublisherp::Serializer.dump(content_item.as_publishable_with_associations)
      )
    end

    it 'adds something to the classes all sorted set when published' do
      expect(all_key_score).to be_nil

      content_item.publish!
      
      expect(all_key_score).to_not be_nil
    end

    it 'removes an item from redis when it is unpublished' do
      content_item.publish!
      content_item.unpublish!

      expect($redis.get(Ublisherp::RedisKeys.key_for(content_item))).to be_nil
    end

    it 'removes something to the classes all sorted set when unpublished' do
      content_item.publish!
      content_item.unpublish!

      expect(all_key_score).to be_nil
    end

    it 'adds an unpublished key to the gone_keys set' do
      content_item.publish!
      content_item.unpublish!

      expect($redis.sismember(
        Ublisherp::RedisKeys.gone,
        Ublisherp::RedisKeys.key_for(content_item))).to be_true
    end

    it "unpublishes dependent associations on unpublish" do
      content_item.publish!
      ci2 = content_item.dup
      ci2.save!
      ci2.publish!
      expect($redis.get(Ublisherp::RedisKeys.key_for(content_item))).
        to be_present
      expect($redis.get(Ublisherp::RedisKeys.key_for(ci2))).
        to be_present

      section.unpublish!
      expect($redis.get(Ublisherp::RedisKeys.key_for(content_item))).
        to_not be_present
      expect($redis.get(Ublisherp::RedisKeys.key_for(ci2))).
        to_not be_present
    end

    it 'runs after callbacks on publish' do
      content_item.should_receive(:before_publish_callback_test)
      content_item.should_receive(:before_first_publish_callback_test)
      content_item.should_receive(:after_publish_callback_test)
      content_item.should_receive(:after_first_publish_callback_test)
      content_item.should_receive(:before_add_to_stream_callback_test).
        at_least(:once)
      content_item.should_receive(:before_add_to_type_stream_callback_test).
        at_least(:once)
      content_item.should_receive(:after_add_to_stream_callback_test).
        at_least(:once)
      content_item.should_receive(:after_add_to_type_stream_callback_test).
        at_least(:once)
      content_item.should_receive(:before_first_add_to_stream_callback_test).
        at_least(:once)
      content_item.should_receive(
        :before_first_add_to_type_stream_callback_test).at_least(:once)
      content_item.should_receive(:after_first_add_to_stream_callback_test).
        at_least(:once)
      content_item.should_receive(:after_first_add_to_type_stream_callback_test).
        at_least(:once)
      content_item.should_not_receive(:after_remove_from_stream_callback_test)
      content_item.should_not_receive(
        :after_remove_from_type_stream_callback_test)
      content_item.publish!
    end

    it "only runs 'first' callbacks on first publish" do
      content_item.publish!
      content_item.should_not_receive(:before_first_publish_callback_test)
      content_item.should_not_receive(:after_first_publish_callback_test)
      content_item.should_not_receive(:before_first_add_to_stream_callback_test)
      content_item.should_not_receive(
        :before_first_add_to_type_stream_callback_test)
      content_item.should_not_receive(:after_first_add_to_stream_callback_test)
      content_item.should_not_receive(
        :after_first_add_to_type_stream_callback_test)
      content_item.publish!
    end


    it 'runs before callbacks on unpublish' do
      content_item.should_receive(:before_unpublish_callback_test)
      content_item.should_receive(:before_unpublish_commit_callback_test)
      content_item.should_receive(:after_unpublish_callback_test)
      content_item.unpublish!
    end

    it 'also publishes associated objects 
        declared with publishes_associations' do
      content_item.tags << tag
      content_item.save!
      content_item.publish!

      expect($redis.get(Ublisherp::RedisKeys.key_for(tag))).to_not be_nil
      expect($redis.get(Ublisherp::RedisKeys.key_for(section))).to_not be_nil
    end

    it "unpublishes multiple missing associated objects when a new one is published" do

      tag2 = Tag.create!(name: "Bread")
      tag3 = Tag.create!(name: "Peaches")
      tag4 = Tag.create!(name: "Herring")
      tag5 = Tag.create!(name: "Ostrich")

      content_item.tags = [tag, tag2, tag3]
      content_item.save!
      content_item.publish!

      expect(Set.new($redis.smembers(
        Ublisherp::RedisKeys.key_for_associations(content_item, :tags)))).to \
        eq(Set.new([tag, tag2, tag3].map { |t|
          Ublisherp::RedisKeys.key_for(t)
        }))

      content_item.tags = [tag3, tag4, tag5]
      content_item.save!
      content_item.publish!

      expect(Set.new($redis.smembers(
        Ublisherp::RedisKeys.key_for_associations(content_item, :tags)))).to \
        eq(Set.new([tag3, tag4, tag5].map { |t|
          Ublisherp::RedisKeys.key_for(t)
        }))
    end

    it 'publishes a content item to a tag stream' do
      content_item.tags << tag
      content_item.save!
      content_item.publish!

      wrong_stream_key = Ublisherp::RedisKeys.key_for_stream_of(content_item,
                                                                :all)
      content_key = Ublisherp::RedisKeys.key_for(content_item)
      expect($redis.zcard(wrong_stream_key)).to eq(0)

      [tag, section].each do |o|
        stream_key = Ublisherp::RedisKeys.key_for_stream_of(o, :all)
        expect($redis.zrange(stream_key, 0, -1)).to eq([content_key])
      end
    end

    it 'adds each stream to the "in_streams" set for each item' do
      content_item.tags << tag
      content_item.save!

      stream_set_key = Ublisherp::RedisKeys.key_for_streams_set(content_item)

      expect($redis.scard(stream_set_key)).to eq(0)

      content_item.publish!

      stream_keys = [[tag, :all], [section, :all],
                     [section, :visible_content_items],
                     [section, :if_stream_in], [section, :unless_stream_in],
                     [section, :content_items]].map do |o|
        Ublisherp::RedisKeys.key_for_stream_of *o
      end
      stream_keys.concat [[ContentItem, :all], [ContentItem, :visible]].map { |o|
        Ublisherp::RedisKeys.key_for_type_stream_of *o
      }

      expect($redis.smembers(stream_set_key)).to match_array(stream_keys)
    end

    it 'unpublishes a content item from a tag stream 
        and its "in streams" key' do
      content_item.tags << tag
      content_item.save!
      content_item.publish!
      content_item.unpublish!

      content_key = Ublisherp::RedisKeys.key_for(content_item)
      stream_set_key = Ublisherp::RedisKeys.key_for_streams_set(content_item)
      
      [[tag, :all], [section, :all], [section, :visible_content_items]].each do |o|
        stream_key = Ublisherp::RedisKeys.key_for_stream_of(*o)
        expect($redis.zrange(stream_key, 0, -1)).to eq([])
        expect($redis.scard(stream_set_key)).to eq(0)
      end
    end

    it "unpublishes from a stream when the item should no longer be in it" do
      expect(content_item.visible?).to be_true
      content_item.publish!

      content_key = Ublisherp::RedisKeys.key_for(content_item)
      stream_key = Ublisherp::RedisKeys.key_for_stream_of(section, :visible_content_items)
      streams_set_key = Ublisherp::RedisKeys.key_for_streams_set(content_item)

      expect($redis.zrange(stream_key, 0, -1)).to eq([content_key])
      expect($redis.sismember(streams_set_key, stream_key)).to be_true

      content_item.visible = false
      content_item.save!
      content_item.should_receive(:after_remove_from_stream_callback_test)
      content_item.publish!

      expect($redis.zrange(stream_key, 0, -1)).to eq([])
      expect($redis.sismember(streams_set_key, stream_key)).to be_false
    end

    it 'tracks associations and unpublishes itself from old ones' do

      t1 = Tag.new name: 'Tag 1'
      t2 = Tag.new name: 'Tag 2'

      content_item.tags << t1
      content_item.tags << t2
      content_item.save!

      content_item.publish!

      t1_stream_key =  Ublisherp::RedisKeys.key_for_stream_of(t1, :all)
      t2_stream_key = Ublisherp::RedisKeys.key_for_stream_of(t2, :all)
      section_stream_key = Ublisherp::RedisKeys.key_for_stream_of(section, :all)

      expect($redis.zcount(t1_stream_key,  '-inf', '+inf')).to eq(1)
      expect($redis.zcount(t2_stream_key, '-inf', '+inf')).to eq(1)
      expect($redis.zcount(section_stream_key, '-inf', '+inf')).to eq(1)

      content_item.tags = []
      content_item.tags << t2
      content_item.section = nil
      content_item.save!
      content_item.publish!

      expect($redis.zcount(t1_stream_key,  '-inf', '+inf')).to eq(0)
      expect($redis.zcount(t2_stream_key, '-inf', '+inf')).to eq(1)
      expect($redis.zcount(section_stream_key, '-inf', '+inf')).to eq(0)
    end

    it 'uses the given stream score if defined' do
      content_item.tags << tag
      content_item.save!

      score_should = content_item.ublisherp_stream_score

      content_item.publish!

      stream_key = Ublisherp::RedisKeys.key_for_stream_of(tag, :all)
      stream = $redis.zrangebyscore(stream_key, '-inf', '+inf', withscores: true)

      expect(stream.first.last).to eq(score_should)
    end

    it 'indexes a content item by its slug' do
      content_item.slug = 'a-crazy-badger'
      content_item.save!
      content_item.publish!
      content_item_key = Ublisherp::RedisKeys.key_for(content_item)

      index_key1 = Ublisherp::RedisKeys.key_for_index(content_item, :slug)
      expect($redis.smembers(index_key1)).to match_array([content_item_key])

      content_item.slug = 'a-hungry-snake'
      content_item.save!
      index_key2 = Ublisherp::RedisKeys.key_for_index(content_item, :slug)
      content_item.publish!

      expect($redis.smembers(index_key1)).to match_array([])
      expect($redis.smembers(index_key2)).to match_array([content_item_key])

      content_item.unpublish!
      expect($redis.smembers(index_key1)).to eq([])
      expect($redis.smembers(index_key2)).to eq([])
    end

    it 'also publishes an inherited model to the right stream' do
      inherited_content_item.save!
      inherited_content_item.publish!

      ici_key = Ublisherp::RedisKeys.key_for(inherited_content_item)
      stream_key = Ublisherp::RedisKeys.key_for_stream_of(section, :inherited_content_items)

      expect($redis.zrange(stream_key, 0, -1)).to match_array([ici_key])
    end

    it 'has the correct publishable associations for subclasses' do
      content_item.publish_association_attrs.to_a.
        should match_array(%i[section tags])
      inherited_content_item.publish_association_attrs.to_a.
        should match_array(%i[region section tags])
    end

    it "publishes a type stream of content items" do
      content_item.save!
      content_item.publish!
      content_item_key = Ublisherp::RedisKeys.key_for(content_item)

      stream_key = Ublisherp::RedisKeys.key_for_type_stream_of(ContentItem, :all)
      expect($redis.zrange(stream_key, 0, -1)).to eq([content_item_key])
    end

    it "publishes a visible content item to the visible content item type stream" do
      content_item.visible = true
      content_item.save!
      content_item.publish!
      content_item_key = Ublisherp::RedisKeys.key_for(content_item)


      stream_key = Ublisherp::RedisKeys.key_for_type_stream_of(ContentItem,
                                                               :visible)
      expect($redis.zrange(stream_key, 0, -1)).to eq([content_item_key])
    end

    it "publishes a visible content item to the visible content item type stream" do
      content_item.visible = false
      content_item.save!
      content_item.publish!
      content_item_key = Ublisherp::RedisKeys.key_for(content_item)


      stream_key = Ublisherp::RedisKeys.key_for_type_stream_of(ContentItem,
                                                               :visible)
      expect($redis.zrange(stream_key, 0, -1)).to eq([])
    end

  end
end

