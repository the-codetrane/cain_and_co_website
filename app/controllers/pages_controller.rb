class PagesController < ApplicationController
  # Public, account-free pages. Inherits ApplicationController's public-by-default access.
  def home
    @upcoming_shows = Show.upcoming.limit(3)
  end

  # Press quotes shown on /about and /epk. Quotes contain HTML entities and are
  # rendered html_safe — keep them hand-authored constants, never user input.
  REVIEWS = [
    {
      quote: "Cain &amp; Co were the perfect headline act&hellip; their energy, professionalism and musicianship is second to none. Glorious Rock and Roll at its absolute finest!",
      author: "Paul Bowser",
      source: "Summit Brewing Co."
    },
    {
      quote: "Cain and Co came, saw, and conquered our patio at Omni Brewing Co in Maple Grove for our Kolschfest celebration. I can&rsquo;t recommend this rocking group enough!",
      author: "Paul Canavati",
      source: "Omni Brewing"
    }
  ].freeze

  def about
    @photos = Photo.published.with_attached_image
    @videos = Video.visible
    @reviews = REVIEWS
  end

  EPK_VIDEO_LIMIT = 3
  EPK_PHOTO_LIMIT = 5
  EPK_PAST_SHOW_LIMIT = 50

  # Booker-facing electronic press kit. Unlisted: not in the nav or sitemap, and
  # marked noindex — it's shared by direct link in booking emails.
  def epk
    response.headers["X-Robots-Tag"] = "noindex, nofollow"

    # Hand-picked (EPK-flagged) media first; until some are flagged, fall back to
    # the newest full-length videos / first published photos so the page is never empty.
    @videos = Video.epk.limit(EPK_VIDEO_LIMIT).presence ||
              Video.visible.where(short: false).limit(EPK_VIDEO_LIMIT)
    photos = Photo.joins(:image_attachment).with_attached_image
    @photos = photos.epk.limit(EPK_PHOTO_LIMIT).presence ||
              photos.published.limit(EPK_PHOTO_LIMIT)

    @upcoming_shows = Show.upcoming.limit(5)
    @past_shows = Show.played.limit(EPK_PAST_SHOW_LIMIT)
    @shows_played = Show.played.count
    # One aggregate query over the shows that have a recorded headcount.
    @counted_shows, @total_attendance, @best_attendance =
      Show.played.unscope(:order).where.not(attendance: nil)
          .pick(Arel.sql("COUNT(*)"), Arel.sql("SUM(attendance)"), Arel.sql("MAX(attendance)"))
    @subscriber_count = Subscriber.active.count
    @reviews = REVIEWS
  end

  # Legal pages. LAST_UPDATED is rendered on both and should be bumped whenever
  # the policy text changes.
  LAST_UPDATED = Date.new(2026, 10, 30)

  def privacy
    @last_updated = LAST_UPDATED
  end

  def tos
    @last_updated = LAST_UPDATED
  end
end
