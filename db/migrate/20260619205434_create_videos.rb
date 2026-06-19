class CreateVideos < ActiveRecord::Migration[8.1]
  def change
    create_table :videos do |t|
      t.string   :youtube_id,    null: false
      t.string   :title,         null: false
      t.string   :thumbnail_url
      t.datetime :published_at,  null: false
      t.boolean  :visible,       null: false, default: true
      t.boolean  :short,         null: false, default: false

      t.timestamps
    end

    add_index :videos, :youtube_id, unique: true
    add_index :videos, :published_at
  end
end
