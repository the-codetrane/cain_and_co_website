class PagesController < ApplicationController
  # Public, account-free pages. Inherits ApplicationController's public-by-default access.
  def home
    @upcoming_shows = Show.upcoming.limit(3)
  end

  def about
    @photos = Photo.published.with_attached_image
    @videos = Video.visible
  end
end
