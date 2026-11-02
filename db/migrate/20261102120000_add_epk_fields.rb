class AddEpkFields < ActiveRecord::Migration[8.1]
  def change
    # Headcount for a played show, entered by hand in admin (Bandsintown doesn't report it).
    add_column :shows, :attendance, :integer
    # Curates which videos/photos lead the booker-facing /epk page.
    add_column :videos, :epk, :boolean, default: false, null: false
    add_column :photos, :epk, :boolean, default: false, null: false
  end
end
