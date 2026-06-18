class CreateOrderItems < ActiveRecord::Migration[8.1]
  def change
    create_table :order_items do |t|
      t.references :order, null: false, foreign_key: true
      # variant may be deleted; snapshot the name for display
      t.references :variant, null: true, foreign_key: true
      t.string :variant_name, null: false
      t.integer :unit_price_cents, null: false
      t.integer :quantity, null: false

      t.timestamps
    end
  end
end
