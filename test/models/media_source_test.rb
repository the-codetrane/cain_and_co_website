require "test_helper"

class MediaSourceTest < ActiveSupport::TestCase
  SPACES_URL = "https://bucket.sfo3.example.test/Product%20Images/abc"

  setup do
    @product = products(:published_shirt)
    @product.images.attach(io: file_fixture("test_photo.gif").open, filename: "shirt.gif", content_type: "image/gif")
    @image = @product.images.first
  end

  test "keeps the attachment on a private service" do
    assert_same @image, MediaSource.for(@image)
  end

  test "swaps in the CDN host on a public service" do
    with_cdn_host("cdn.example.test") do
      on_public_service do
        @image.blob.stub(:url, SPACES_URL) do
          assert_equal "https://cdn.example.test/Product%20Images/abc", MediaSource.for(@image)
        end
      end
    end
  end

  test "uses the object's own URL when no CDN host is configured" do
    on_public_service do
      @image.blob.stub(:url, SPACES_URL) do
        assert_equal SPACES_URL, MediaSource.for(@image)
      end
    end
  end

  test "keeps a variant that hasn't been generated so its route can create it" do
    variant = @image.variant(:card)

    on_public_service do
      assert_same variant, MediaSource.for(variant)
    end
  end

  test "links a generated variant directly" do
    variant = @image.variant(:card).processed

    with_cdn_host("cdn.example.test") do
      on_public_service do
        variant.image.blob.stub(:url, SPACES_URL) do
          variant.stub(:image, variant.image) do
            assert_equal "https://cdn.example.test/Product%20Images/abc", MediaSource.for(variant)
          end
        end
      end
    end
  end

  test "uploads to Spaces are marked cacheable forever" do
    upload = Rails.configuration.active_storage.service_configurations.dig("digitalocean", "upload")
    assert_equal "public, max-age=31536000, immutable", upload["cache_control"]
  end

  private

  def on_public_service(&block)
    @image.blob.service.stub(:public?, true, &block)
  end

  def with_cdn_host(host)
    Rails.configuration.x.media_cdn_host = host
    yield
  ensure
    Rails.configuration.x.media_cdn_host = nil
  end
end
