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
