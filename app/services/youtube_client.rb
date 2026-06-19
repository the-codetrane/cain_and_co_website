require "net/http"
require "rexml/document"
require "rexml/xpath"

# Fetches the band's YouTube video feed via the public Atom RSS feed.
# No API key required — YouTube publishes this feed for every channel.
#
# Channel: https://www.youtube.com/@cainandcoband
class YoutubeClient
  CHANNEL_ID  = "UCOeD6vWVnKx_ZPD66-dK04g".freeze
  FEED_URL    = "https://www.youtube.com/feeds/videos.xml?channel_id=#{CHANNEL_ID}".freeze
  NAMESPACES  = {
    "atom"  => "http://www.w3.org/2005/Atom",
    "yt"    => "http://www.youtube.com/xml/schemas/2015",
    "media" => "http://search.yahoo.com/mrss/"
  }.freeze
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 10

  Error = Class.new(StandardError)

  # Returns an array of hashes:
  #   { youtube_id:, title:, thumbnail_url:, published_at:, short: }
  def videos
    parse_feed(fetch_feed)
  end

  private

  def fetch_feed
    uri = URI(FEED_URL)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                               open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
      http.get(uri.request_uri, "Accept" => "application/atom+xml")
    end

    unless response.is_a?(Net::HTTPSuccess)
      raise Error, "YouTube feed request failed (#{response.code}): #{response.body&.truncate(200)}"
    end

    response.body
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError => e
    raise Error, "YouTube feed error: #{e.class}: #{e.message}"
  end

  def parse_feed(xml)
    doc = REXML::Document.new(xml)
    entries = []

    REXML::XPath.each(doc, "//atom:entry", NAMESPACES) do |entry|
      youtube_id    = REXML::XPath.first(entry, "yt:videoId",                    NAMESPACES)&.text
      title         = REXML::XPath.first(entry, "atom:title",                    NAMESPACES)&.text
      thumbnail_url = REXML::XPath.first(entry, "media:group/media:thumbnail",   NAMESPACES)&.attributes&.[]("url")
      published_str = REXML::XPath.first(entry, "atom:published",                NAMESPACES)&.text
      link_href     = REXML::XPath.first(entry, "atom:link[@rel='alternate']",   NAMESPACES)&.attributes&.[]("href")

      next if youtube_id.blank? || title.blank? || published_str.blank?

      entries << {
        youtube_id:    youtube_id,
        title:         title,
        thumbnail_url: thumbnail_url,
        published_at:  Time.parse(published_str),
        short:         link_href.to_s.include?("/shorts/")
      }
    end

    entries
  rescue REXML::ParseException => e
    raise Error, "YouTube feed parse error: #{e.message}"
  end
end
