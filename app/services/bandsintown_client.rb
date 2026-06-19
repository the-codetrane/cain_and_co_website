require "net/http"
require "uri"
require "erb"

# Thin wrapper around the Bandsintown public API (https://rest.bandsintown.com).
#
# Configure via Rails credentials or ENV:
#   bandsintown:
#     app_id: <your app id requested from Bandsintown>
#     artist: id_12345        # stable artist id form (or the artist name)
#
# or BANDSINTOWN_APP_ID / BANDSINTOWN_ARTIST.
class BandsintownClient
  BASE_URL = "https://rest.bandsintown.com".freeze
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 10

  Error = Class.new(StandardError)

  def initialize(app_id: self.class.app_id, artist: self.class.artist)
    @app_id = app_id
    @artist = artist
  end

  # True when both an app_id and artist are configured. The sync job uses this
  # to no-op gracefully before the band has supplied credentials.
  def configured?
    @app_id.present? && @artist.present?
  end

  # date: "upcoming" | "past" | "all" (or "YYYY-MM-DD,YYYY-MM-DD" range)
  # Returns an array of event hashes.
  def events(date: "upcoming")
    result = get("/artists/#{artist_segment}/events", date: date)
    # The API returns an array of events, or an object with a message when none.
    result.is_a?(Array) ? result : []
  end

  # Artist profile (followers, image, links). Returns a hash.
  def artist_info
    get("/artists/#{artist_segment}")
  end

  def self.app_id
    Rails.application.credentials.dig(:bandsintown, :app_id) || ENV["BANDSINTOWN_APP_ID"]
  end

  def self.artist
    Rails.application.credentials.dig(:bandsintown, :artist_id) || ENV["BANDSINTOWN_ARTIST"]
  end

  private

  def artist_segment
    # Bandsintown accepts a name, "id_<id>", or "fbid_<id>"; encode whatever is configured.
    ERB::Util.url_encode(@artist.to_s)
  end

  def get(path, params = {})
    raise Error, "Bandsintown is not configured (missing app_id/artist)" unless configured?

    uri = URI("#{BASE_URL}#{path}")
    uri.query = URI.encode_www_form(params.merge(app_id: @app_id))

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                              open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
      http.get(uri.request_uri, "Accept" => "application/json")
    end

    unless response.is_a?(Net::HTTPSuccess)
      raise Error, "Bandsintown request failed (#{response.code}): #{response.body&.truncate(200)}"
    end

    JSON.parse(response.body)
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError => e
    raise Error, "Bandsintown request error: #{e.class}: #{e.message}"
  rescue JSON::ParserError => e
    raise Error, "Bandsintown returned invalid JSON: #{e.message}"
  end
end
