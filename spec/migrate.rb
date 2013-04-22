class CreateSchema < ActiveRecord::Migration
  create_table :content_items

  create_table :tags do |t|
    t.string :name
  end

  create_table :content_items_tags, id: false do |t|
    t.integer :content_item_id
    t.integer :tag_id
  end
end
