class ShowsController < ApplicationController
  # Public, account-free. Data comes from the locally-synced Show table.
  def index
    @shows = Show.upcoming
  end

  def past
    @shows = Show.past.limit(100)
  end
end
