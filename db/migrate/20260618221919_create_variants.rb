class CreateVariants < ActiveRecord::Migration[8.1]
  def change
    create_table :variants do |t|
      t.references :product, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :price_cents, null: false, default: 0
      t.integer :stock_quantity, null: false, default: 0
      t.string :sku

      t.timestamps
    end
    add_index :variants, :sku, unique: true, where: "sku IS NOT NULL"
  end
end
