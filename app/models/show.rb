class Show < ApplicationRecord
  STATUSES = %w[active canceled].freeze
  SOURCES = %w[bandsintown manual].freeze

  validates :title, :starts_at, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :source, inclusion: { in: SOURCES }
  # Bandsintown shows carry a unique event id; manual shows leave it nil.
  validates :bandsintown_id, uniqueness: true, allow_nil: true

  scope :active, -> { where(status: "active") }
  scope :canceled, -> { where(status: "canceled") }
  scope :bandsintown, -> { where(source: "bandsintown") }
  scope :manual, -> { where(source: "manual") }
  scope :upcoming, -> { active.where(starts_at: Time.current..).order(:starts_at) }
  scope :past, -> { where(starts_at: ..Time.current).order(starts_at: :desc) }
  scope :featured, -> { active.where(featured: true) }

  def canceled?
    status == "canceled"
  end

  # The first available ticket offer, if any.
  def ticket_url
    Array(offers).find { |o| o.is_a?(Hash) && o["url"].present? }&.dig("url")
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
      bandsintown_url: payload["url"]
    )
    show.save!
    show
  end
end
