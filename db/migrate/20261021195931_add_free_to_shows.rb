class AddFreeToShows < ActiveRecord::Migration[8.1]
  def change
    add_column :shows, :free, :boolean, default: false, null: false
  end
end
