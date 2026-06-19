require "test_helper"

class YoutubeClientTest < ActiveSupport::TestCase
  SAMPLE_FEED = <<~XML
    <?xml version="1.0" encoding="UTF-8"?>
    <feed xmlns="http://www.w3.org/2005/Atom"
          xmlns:yt="http://www.youtube.com/xml/schemas/2015"
          xmlns:media="http://search.yahoo.com/mrss/">
      <entry>
        <id>yt:video:rzTzsWmexfM</id>
        <yt:videoId>rzTzsWmexfM</yt:videoId>
        <yt:channelId>UCOeD6vWVnKx_ZPD66-dK04g</yt:channelId>
        <title>Medicine Woman</title>
        <link rel="alternate" href="https://www.youtube.com/shorts/rzTzsWmexfM"/>
        <published>2025-08-01T17:03:07+00:00</published>
        <media:group>
          <media:thumbnail url="https://i3.ytimg.com/vi/rzTzsWmexfM/hqdefault.jpg"/>
          <media:description>Great song</media:description>
        </media:group>
      </entry>
      <entry>
        <id>yt:video:hq-O6F957Eg</id>
        <yt:videoId>hq-O6F957Eg</yt:videoId>
        <yt:channelId>UCOeD6vWVnKx_ZPD66-dK04g</yt:channelId>
        <title>Live at the Venue</title>
        <link rel="alternate" href="https://www.youtube.com/watch?v=hq-O6F957Eg"/>
        <published>2024-06-01T12:00:00+00:00</published>
        <media:group>
          <media:thumbnail url="https://i3.ytimg.com/vi/hq-O6F957Eg/hqdefault.jpg"/>
          <media:description>Live show</media:description>
        </media:group>
      </entry>
    </feed>
  XML

  setup do
    @client = YoutubeClient.new
  end

  test "videos returns array of attribute hashes" do
    stub_http_success(SAMPLE_FEED) do
      videos = @client.videos
      assert_equal 2, videos.size
    end
  end

  test "parses youtube_id and title" do
    stub_http_success(SAMPLE_FEED) do
      v = @client.videos.first
      assert_equal "rzTzsWmexfM", v[:youtube_id]
      assert_equal "Medicine Woman", v[:title]
    end
  end

  test "detects Shorts from link href" do
    stub_http_success(SAMPLE_FEED) do
      videos = @client.videos
      assert     videos[0][:short], "shorts URL should be detected"
      assert_not videos[1][:short], "watch URL should not be detected as short"
    end
  end

  test "parses thumbnail_url" do
    stub_http_success(SAMPLE_FEED) do
      v = @client.videos.first
      assert_equal "https://i3.ytimg.com/vi/rzTzsWmexfM/hqdefault.jpg", v[:thumbnail_url]
    end
  end

  test "raises Error on non-2xx response" do
    stub_http_error("403") do
      assert_raises(YoutubeClient::Error) { @client.videos }
    end
  end

  test "raises Error on network timeout" do
    Net::HTTP.stub(:start, ->(*) { raise Net::OpenTimeout }) do
      assert_raises(YoutubeClient::Error) { @client.videos }
    end
  end

  private

  def stub_http_success(body, &block)
    fake_response = Struct.new(:body) do
      def is_a?(klass) = klass == Net::HTTPSuccess
    end.new(body)
    Net::HTTP.stub(:start, ->(*) { fake_response }, &block)
  end

  def stub_http_error(code, &block)
    fake_response = Struct.new(:code, :body) do
      def is_a?(_) = false
    end.new(code, "")
    Net::HTTP.stub(:start, ->(*) { fake_response }, &block)
  end
end
