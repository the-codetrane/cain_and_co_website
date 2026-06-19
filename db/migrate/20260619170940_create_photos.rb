class CreatePhotos < ActiveRecord::Migration[8.1]
  def change
    create_table :photos do |t|
      t.string :caption
      t.integer :position, null: false, default: 1
      t.boolean :published, null: false, default: true

      t.timestamps
    end
  end
end
