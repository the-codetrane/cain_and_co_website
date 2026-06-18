class CreateDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :deliveries do |t|
      t.references :newsletter, null: false, foreign_key: true
      t.references :subscriber, null: false, foreign_key: true
      t.integer :status, null: false, default: 0
      t.text :error
      t.datetime :sent_at

      t.timestamps
    end

    # One delivery per (newsletter, subscriber) — makes per-recipient sends
    # idempotent: re-running the send pipeline can't create a duplicate row.
    add_index :deliveries, [ :newsletter_id, :subscriber_id ], unique: true
  end
end
