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

  test "upcoming shows list the event and its venue" do
    get epk_path
    item = css_select("#shows li").find { |li| li.text.include?(shows(:upcoming).title) }
    assert item, "upcoming show missing"
    assert_includes item.text, shows(:upcoming).venue_name
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

  test "replaces the fan nav and push prompt with a booker header" do
    get epk_path
    assert_select "a[href=?]", cart_path, count: 0
    assert_select "a[href=?]", new_session_path, count: 0
    assert_select "[data-controller=push-notifications]", count: 0
    assert_select "header a[href^=?]", "mailto:booking@cainandco.band?subject=", text: "Request a date"
  end

  test "request-a-date email is prefilled with what a booker needs to send" do
    get epk_path
    href = css_select("header a").find { |a| a.text == "Request a date" }["href"]
    body = CGI.unescape(href[/body=([^&]+)/, 1])
    %w[Date(s): Venue: Capacity: Budget].each { |field| assert_includes body, field }
  end

  test "synced shows whose venue is just the title list the title once" do
    shows(:past).update!(title: "Rogue Royal w. Cain & Co.", venue_name: "Rogue Royal w. Cain & Co.")
    get epk_path
    row = css_select("#shows table tbody tr").first
    assert_equal "—", row.css("td")[1].css("span").first.text
    assert_equal "Rogue Royal w. Cain & Co.", row.css("td")[2].text.strip
  end

  test "show history shows the latest 10 and collapses the rest" do
    11.times { |i| Show.create!(title: "Gig #{i}", starts_at: (i + 40).days.ago, source: "manual") }
    get epk_path
    assert_select "#shows tbody:not([hidden]) tr", 10
    assert_select "#shows tbody[hidden][data-reveal-target=item] tr", Show.played.count - 10
    assert_select "#shows button[data-action='reveal#show']", text: /Show all #{Show.played.count} shows/
  end

  test "upcoming shows with tickets on sale get a Tickets link" do
    get epk_path
    assert_select "#shows li a[href=?]", "https://tickets.example.com/echo", text: "Tickets"
  end

  test "meta tags are escaped once, with a large share image" do
    get epk_path
    assert_select "meta[property='og:title'][content=?]", "EPK · Cain & Co."
    assert_select "meta[name='twitter:card'][content=summary_large_image]"
    assert_select "meta[property='og:image'][content^=?]", "http://www.example.com/rails/active_storage/blobs/"
    assert_no_match(/&amp;amp;/, response.body)
  end
end
