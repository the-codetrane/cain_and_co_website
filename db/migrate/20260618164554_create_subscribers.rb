class CreateSubscribers < ActiveRecord::Migration[8.1]
  def change
    create_table :subscribers do |t|
      t.string :email, null: false
      t.datetime :confirmed_at
      t.datetime :unsubscribed_at

      t.timestamps
    end
    add_index :subscribers, :email, unique: true
  end
end
