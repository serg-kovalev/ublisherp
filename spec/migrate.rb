ActiveRecord::Migration.verbose = false
class CreateSchema < ActiveRecord::Migration
  create_table :content_items do |t|
    t.string :type
    t.integer :section_id
    t.string :slug
    t.datetime :null_datetime_at, null: true
    t.integer :stream_score, null: true
    t.boolean :visible, null: false, default: true
    t.integer :region_id, null: true
    t.timestamps
  end

  create_table :sections do |t|
    t.string :name
    t.timestamps
  end

  create_table :tags do |t|
    t.string :name
  end

  create_table :content_items_tags, id: false do |t|
    t.integer :content_item_id
    t.integer :tag_id
  end

  create_table :regions
end
