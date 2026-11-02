require "test_helper"

class EpkTest < ActionDispatch::IntegrationTest
  test "epk is public and unlisted (noindex)" do
    get epk_path
    assert_response :success
    assert_select "h1", "Cain & Co."
    assert_select "meta[name=robots][content=?]", "noindex, nofollow"
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
  end

  test "epk is not linked from the sitemap" do
    get sitemap_path(format: :xml)
    assert_not_includes response.body, epk_url
  end

  test "contact info is at the top as clickable links" do
    get epk_path
    assert_select "a[href^=?]", "mailto:booking@cainandco.band"
    assert_select "a[href=?]", "tel:+16122345305"
  end

  test "show history table lists played shows with attendance, newest first" do
    shows(:past).update!(attendance: 85)
    Show.create!(title: "Turf Club night", venue_name: "Turf Club", city: "St. Paul",
                         starts_at: 60.days.ago, source: "manual")
    Show.create!(title: "Pulled gig", venue_name: "Nowhere", starts_at: 45.days.ago,
                 source: "manual", status: "canceled")

    get epk_path
    rows = css_select("#shows table tbody tr")
    assert_equal [ "The Basement", "Turf Club" ], rows.map { |r| r.css("td")[1].css("span").first.text }
    assert_match "85", rows.first.css("td").last.text
    assert_match "—", rows.last.css("td").last.text
    assert_not_includes response.body, "Pulled gig"
  end

  test "draw stats only report headcounts that were recorded" do
    get epk_path
    assert_select "#draw dt", text: "Average headcount", count: 0

    shows(:past).update!(attendance: 80)
    Show.create!(title: "Turf Club", venue_name: "Turf Club", starts_at: 60.days.ago,
                 source: "manual", attendance: 100)
    get epk_path
    assert_select "#draw dt", text: "Average headcount"
    assert_select "#draw dd", text: "90"
    assert_select "#draw dd", text: "100"
  end

  test "draw section cites ticket sales" do
    get epk_path
    assert_select "#draw li", text: /\$1,000\s+in ticket sales at\s+Zhora Darling/
    assert_select "#draw li", text: /\$475\s+in ticket sales at\s+KJ’s Hideaway/
  end

  test "mailing list stat counts only confirmed subscribers" do
    expected = Subscriber.active.count + 1
    Subscriber.create!(email: "epk-fan@example.com", confirmed_at: Time.current)
    Subscriber.create!(email: "epk-pending@example.com")
    get epk_path
    assert_select "#draw div", text: /Mailing list\s*#{expected}\b/
  end

  test "upcoming shows are listed" do
    get epk_path
    assert_select "#shows a", text: shows(:upcoming).venue_name
  end

  test "EPK-flagged videos lead; falls back to full-length visible videos" do
    get epk_path
    # Only non-short visible videos qualify for the fallback; fixtures have none.
    assert_select "#video", count: 0

    videos(:medicine_woman).update!(epk: true)
    get epk_path
    assert_select "#video [data-youtube-facade-src-value=?]", videos(:medicine_woman).embed_url
    assert_select "#video [data-youtube-facade-src-value=?]", videos(:late_night_chats).embed_url, count: 0
  end

  test "hidden videos never appear even if flagged" do
    videos(:hidden_video).update!(epk: true)
    get epk_path
    assert_select "[data-youtube-facade-src-value=?]", videos(:hidden_video).embed_url, count: 0
  end

  test "stage plot is downloadable" do
    assert File.exist?(Rails.public_path.join("epk/cain-and-co-stage-plot.pdf"))
    get epk_path
    assert_select "a[href=?][download]", "/epk/cain-and-co-stage-plot.pdf"
  end
end
