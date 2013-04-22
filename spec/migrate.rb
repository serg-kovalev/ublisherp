class CreateSchema < ActiveRecord::Migration
  create_table :content_items
  create_table :tags

  create_table :content_items_tags, id: false do |t|
    t.integer :content_item_id
    t.integer :tag_id
  end
end
