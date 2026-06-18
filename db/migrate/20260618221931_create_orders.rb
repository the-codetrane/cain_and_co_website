class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.string :status, null: false, default: "pending"
      t.string :buyer_name
      t.string :buyer_email
      t.string :shipping_name
      t.string :shipping_address1
      t.string :shipping_address2
      t.string :shipping_city
      t.string :shipping_state
      t.string :shipping_zip
      t.string :shipping_country
      t.integer :subtotal_cents, null: false, default: 0
      t.integer :shipping_cents, null: false, default: 0
      t.integer :total_cents, null: false, default: 0
      t.string :stripe_checkout_session_id
      t.string :stripe_payment_intent_id

      t.timestamps
    end
    add_index :orders, :stripe_checkout_session_id, unique: true, where: "stripe_checkout_session_id IS NOT NULL"
    add_index :orders, :status
  end
end
