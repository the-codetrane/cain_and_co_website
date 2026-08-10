class PagesController < ApplicationController
  # Public, account-free pages. Inherits ApplicationController's public-by-default access.
  def home
    @upcoming_shows = Show.upcoming.limit(3)
  end

  def about
    @photos = Photo.published.with_attached_image
    @videos = Video.visible
  end

  # Legal pages. LAST_UPDATED is rendered on both and should be bumped whenever
  # the policy text changes.
  LAST_UPDATED = Date.new(2026, 8, 10)

  def privacy
    @last_updated = LAST_UPDATED
  end

  def tos
    @last_updated = LAST_UPDATED
  end
end
