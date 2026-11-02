class AddTicketSalesCentsToShows < ActiveRecord::Migration[8.1]
  def change
    # Gross ticket sales for a played show, entered by hand in admin. Proof of draw on /epk.
    add_column :shows, :ticket_sales_cents, :integer
  end
end
