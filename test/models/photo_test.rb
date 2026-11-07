require "test_helper"

class PhotoTest < ActiveSupport::TestCase
  GIF = File.binread(Rails.root.join("test/fixtures/files/test_photo.gif"))

  def attached_photo(**attrs)
    photo = Photo.new({ published: true }.merge(attrs))
    photo.image.attach(io: StringIO.new(GIF), filename: "test.gif", content_type: "image/gif")
    photo
  end

  # ── Validations ──────────────────────────────────────────────────────────

  test "image is required" do
    photo = Photo.new(position: 1, published: true)
    assert_not photo.valid?
    assert_includes photo.errors[:image], "can't be blank"
  end

  test "position must be a positive integer" do
    photo = attached_photo(position: 0)
    assert_not photo.valid?
    assert photo.errors[:position].any?
  end

  # ── Defaults & callbacks ─────────────────────────────────────────────────

  test "position auto-assigns on create when not provided" do
    photo = attached_photo
    photo.position = nil
    photo.valid?
    assert_not_nil photo.position
    assert photo.position > 0
  end

  test "auto-assigned position is one higher than the current max" do
    max_before = Photo.maximum(:position) || 0
    photo = attached_photo
    photo.position = nil
    photo.valid?
    assert_equal max_before + 1, photo.position
  end

  test "published defaults to true" do
    assert Photo.new.published
  end

  # ── Rendering ────────────────────────────────────────────────────────────

  test "image_src is nil when no image is attached" do
    assert_nil Photo.new.image_src
  end

  test "image_src falls back to the attachment on a non-public service" do
    photo = attached_photo(position: 99)
    photo.save!
    assert_not photo.image.blob.service.public?
    assert_equal photo.image, photo.image_src
  end

  test "image_src returns the object URL on a public service" do
    photo = attached_photo(position: 98)
    photo.save!
    photo.image.blob.service.stub(:public?, true) do
      photo.image.blob.stub(:url, "https://example.test/photo.gif") do
        assert_equal "https://example.test/photo.gif", photo.image_src
      end
    end
  end

  test "display returns the named variant for a resizable image" do
    photo = attached_photo(position: 97)
    photo.save!
    assert_instance_of ActiveStorage::VariantWithRecord, photo.display(:carousel)
  end

  test "the carousel variant is a webp" do
    photo = attached_photo(position: 96)
    photo.save!
    variant = photo.display(:carousel).processed
    assert_equal "image/webp", variant.image.content_type
  end

  test "display falls back to the original for a format that can't be resized" do
    photo = attached_photo(position: 95)
    photo.save!
    photo.image.blob.update!(content_type: "application/pdf")
    assert_equal photo.image, photo.display(:carousel)
  end

  # ── Scopes ───────────────────────────────────────────────────────────────

  test "published scope excludes unpublished photos" do
    assert_includes     Photo.published.to_a, photos(:outdoor_shoot)
    assert_includes     Photo.published.to_a, photos(:stage_shot)
    assert_not_includes Photo.published.to_a, photos(:hidden_draft)
  end

  test "published scope orders by position ascending" do
    positions = Photo.published.pluck(:position)
    assert_equal positions.sort, positions
  end
end
