require "test_helper"

class VideoTest < ActiveSupport::TestCase
  # ── Validations ────────────────────────────────────────────────────────

  test "youtube_id is required" do
    v = Video.new(title: "Title", published_at: Time.current)
    assert_not v.valid?
    assert v.errors[:youtube_id].any?
  end

  test "title is required" do
    v = Video.new(youtube_id: "abc123", published_at: Time.current)
    assert_not v.valid?
    assert v.errors[:title].any?
  end

  test "published_at is required" do
    v = Video.new(youtube_id: "abc123", title: "Title")
    assert_not v.valid?
    assert v.errors[:published_at].any?
  end

  test "youtube_id must be unique" do
    dup = Video.new(youtube_id: videos(:medicine_woman).youtube_id,
                    title: "Dup", published_at: Time.current)
    assert_not dup.valid?
    assert dup.errors[:youtube_id].any?
  end

  # ── Scopes ─────────────────────────────────────────────────────────────

  test "visible scope excludes hidden videos" do
    assert_includes     Video.visible.to_a, videos(:medicine_woman)
    assert_includes     Video.visible.to_a, videos(:late_night_chats)
    assert_not_includes Video.visible.to_a, videos(:hidden_video)
  end

  test "visible scope orders by published_at descending" do
    dates = Video.visible.pluck(:published_at)
    assert_equal dates.sort.reverse, dates
  end

  # ── Methods ────────────────────────────────────────────────────────────

  test "embed_url returns youtube-nocookie embed URL" do
    v = videos(:medicine_woman)
    assert_equal "https://www.youtube-nocookie.com/embed/#{v.youtube_id}", v.embed_url
  end
end
