class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string :name, null: false
      t.text :description
      t.boolean :published, null: false, default: false
      t.boolean :featured, null: false, default: false

      t.timestamps
    end
  end
end
