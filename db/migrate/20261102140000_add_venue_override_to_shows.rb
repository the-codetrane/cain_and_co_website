class AddVenueOverrideToShows < ActiveRecord::Migration[8.1]
  def change
    # Real venue name entered in admin. Bandsintown events here carry the event
    # title in venue.name, so the synced venue_name can't be trusted; the sync
    # never writes this column.
    add_column :shows, :venue_override, :string
  end
end
