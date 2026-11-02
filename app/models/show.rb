class Show < ApplicationRecord
  STATUSES = %w[active canceled].freeze
  SOURCES = %w[bandsintown manual].freeze

  validates :title, :starts_at, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :source, inclusion: { in: SOURCES }
  # Bandsintown shows carry a unique event id; manual shows leave it nil.
  validates :bandsintown_id, uniqueness: true, allow_nil: true
  validates :attendance, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  scope :active, -> { where(status: "active") }
  scope :canceled, -> { where(status: "canceled") }
  scope :bandsintown, -> { where(source: "bandsintown") }
  scope :manual, -> { where(source: "manual") }
  scope :upcoming, -> { active.where(starts_at: Time.current..).order(:starts_at) }
  # Exclusive upper bound so a show starting exactly at Time.current is "upcoming", not both.
  scope :past, -> { where(starts_at: ...Time.current).order(starts_at: :desc) }
  scope :featured, -> { active.where(featured: true) }
  # Shows we actually played: past and not canceled. Drives the EPK show history.
  scope :played, -> { active.past }

  def canceled?
    status == "canceled"
  end

  # Best ticketing link for the card's "Tickets" button, or nil when nothing is on
  # sale. Prefers an available Bandsintown offer; for manual shows (which carry no
  # offers) falls back to the admin-entered ticket/info URL. Returns nil for free,
  # canceled or past shows, synced shows whose offers are all sold out, and synced
  # shows with no offers at all (their bandsintown_url is just the event page, not
  # tickets). Free wins over offers: Bandsintown keeps serving stale ticket offers
  # on events the band has since marked "no cover".
  def ticket_url
    return if free? || canceled? || starts_at.past?

    available = Array(offers).find do |o|
      o.is_a?(Hash) && o["url"].present? && offer_available?(o["status"])
    end
    return available["url"] if available

    bandsintown_url.presence if source == "manual"
  end

  def location
    [ city, region, country ].compact_blank.join(", ")
  end

  def map_url
    return if latitude.blank? || longitude.blank?
    "https://www.google.com/maps/search/?api=1&query=#{latitude},#{longitude}"
  end

  # Upsert a Bandsintown events-API payload into a Show, keyed by event id.
  # Returns the persisted Show. Never overwrites manually-created shows.
  def self.from_bandsintown(payload)
    venue = payload["venue"] || {}
    show = find_or_initialize_by(bandsintown_id: payload["id"].to_s)
    show.assign_attributes(
      source: "bandsintown",
      status: "active",
      title: payload["title"].presence || venue["name"],
      description: payload["description"],
      starts_at: payload["starts_at"].presence || payload["datetime"],
      ends_at: payload["ends_at"],
      venue_name: venue["name"],
      city: venue["city"],
      region: venue["region"],
      country: venue["country"],
      latitude: venue["latitude"].presence,
      longitude: venue["longitude"].presence,
      lineup: payload["lineup"],
      offers: payload["offers"],
      free: payload["free"] == true,
      bandsintown_url: payload["url"]
    )
    show.save!
    show
  end

  private

  # Bandsintown offer status is "available" when on sale; treat a missing status as
  # available so we don't hide a valid link, but hide explicitly sold-out offers.
  def offer_available?(status)
    status.blank? || status.to_s.casecmp?("available")
  end
end
