class CreateShows < ActiveRecord::Migration[8.1]
  def change
    create_table :shows do |t|
      t.string :bandsintown_id
      t.string :title
      t.text :description
      t.datetime :starts_at, null: false
      t.datetime :ends_at
      t.string :venue_name
      t.string :city
      t.string :region
      t.string :country
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6
      t.json :lineup
      t.json :offers
      t.string :bandsintown_url
      t.string :status, null: false, default: "active"
      t.boolean :featured, null: false, default: false
      t.string :source, null: false, default: "bandsintown"

      t.timestamps
    end
    # NULL bandsintown_id (manual shows) are allowed; SQLite treats NULLs as distinct.
    add_index :shows, :bandsintown_id, unique: true
    add_index :shows, :starts_at
    add_index :shows, :status
  end
end
