class CreateNewsletters < ActiveRecord::Migration[8.1]
  def change
    create_table :newsletters do |t|
      t.string :subject, null: false
      t.integer :status, null: false, default: 0
      t.datetime :scheduled_at
      t.datetime :sent_at

      t.timestamps
    end
  end
end
