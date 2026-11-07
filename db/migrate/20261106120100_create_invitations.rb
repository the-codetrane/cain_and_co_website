class CreateInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :invitations do |t|
      t.string :email, null: false
      t.boolean :admin, default: false, null: false
      t.datetime :sent_at, null: false

      t.timestamps
    end
    add_index :invitations, :email, unique: true
  end
end
