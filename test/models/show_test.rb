require "test_helper"

class ShowTest < ActiveSupport::TestCase
  test "scopes split upcoming, past, featured" do
    assert_includes Show.upcoming, shows(:upcoming)
    assert_includes Show.upcoming, shows(:manual_upcoming)
    assert_includes Show.past, shows(:past)
    assert_includes Show.featured, shows(:upcoming)
    assert_not_includes Show.featured, shows(:manual_upcoming)
  end

  test "canceled shows are excluded from upcoming" do
    show = shows(:upcoming)
    show.update!(status: "canceled")
    assert_not_includes Show.upcoming, show
  end

  test "ticket_url returns the first available offer url" do
    assert_equal "https://tickets.example.com/echo", shows(:upcoming).ticket_url
    assert_nil shows(:past).ticket_url
  end

  test "ticket_url hides sold-out synced offers" do
    show = shows(:upcoming)
    show.update!(offers: [ { "type" => "Tickets", "url" => "https://x.test", "status" => "sold out" } ])
    assert_nil show.ticket_url
  end

  test "ticket_url falls back to the info url for manual shows" do
    show = Show.create!(title: "House show", starts_at: 3.days.from_now, source: "manual",
                        bandsintown_url: "https://info.test/show")
    assert_equal "https://info.test/show", show.ticket_url
  end

  test "ticket_url is nil for synced shows with no offers" do
    show = shows(:upcoming)
    show.update!(offers: [])
    assert_nil show.ticket_url
  end

  test "ticket_url is nil for free shows even with an available offer" do
    show = shows(:upcoming)
    show.update!(free: true)
    assert_nil show.ticket_url

    manual = Show.create!(title: "Park gig", starts_at: 3.days.from_now, source: "manual",
                          bandsintown_url: "https://info.test/park", free: true)
    assert_nil manual.ticket_url
  end

  test "from_bandsintown stores the free flag" do
    payload = { "id" => "2001", "title" => "No cover night", "starts_at" => 5.days.from_now.iso8601,
                "venue" => { "name" => "The Dugout" }, "free" => true,
                "offers" => [ { "type" => "Tickets", "url" => "https://bit.test/t/2001", "status" => "available" } ] }
    show = Show.from_bandsintown(payload)
    assert show.free?
    assert_nil show.ticket_url

    show = Show.from_bandsintown(payload.merge("free" => false))
    assert_not show.free?
    assert_equal "https://bit.test/t/2001", show.ticket_url
  end

  test "ticket_url is nil for canceled and past shows" do
    show = shows(:upcoming)
    show.update!(status: "canceled")
    assert_nil show.ticket_url

    show.update!(status: "active", starts_at: 1.day.ago)
    assert_nil show.ticket_url
  end

  test "a show starting exactly now is upcoming, not past" do
    freeze_time do
      show = Show.create!(title: "Now", starts_at: Time.current, source: "manual")
      assert_includes Show.upcoming, show
      assert_not_includes Show.past, show
    end
  end

  test "location joins present parts" do
    assert_equal "Los Angeles, CA, United States", shows(:upcoming).location
  end

  test "map_url present only with coordinates" do
    assert shows(:upcoming).map_url.present?
    assert_nil shows(:past).map_url
  end

  test "from_bandsintown upserts by event id and is idempotent" do
    payload = {
      "id" => "5555", "title" => "New Event", "datetime" => 7.days.from_now.iso8601,
      "venue" => { "name" => "Venue", "city" => "Denver", "region" => "CO", "country" => "US" },
      "offers" => [ { "type" => "Tickets", "url" => "https://x.test", "status" => "available" } ],
      "url" => "https://bandsintown.com/e/5555", "lineup" => [ "Cain & Co." ]
    }

    assert_difference -> { Show.count }, 1 do
      Show.from_bandsintown(payload)
    end
    # Re-running updates in place, no duplicate.
    assert_no_difference -> { Show.count } do
      show = Show.from_bandsintown(payload.merge("title" => "Renamed"))
      assert_equal "Renamed", show.title
      assert_equal "bandsintown", show.source
    end
  end

  test "from_bandsintown falls back to starts_at over datetime" do
    payload = {
      "id" => "6", "title" => "T", "starts_at" => "2030-01-01T20:00:00",
      "datetime" => "2020-01-01T20:00:00", "venue" => { "name" => "V" }
    }
    show = Show.from_bandsintown(payload)
    assert_equal 2030, show.starts_at.year
  end

  test "ticket_sales reads and writes whole dollars over cents" do
    show = Show.new(ticket_sales: "$1,000")
    assert_equal 100_000, show.ticket_sales_cents
    assert_equal 1000, show.ticket_sales
    show.ticket_sales = ""
    assert_nil show.ticket_sales_cents
  end

  test "top_ticket_sales lists played shows with sales, best first" do
    low = Show.create!(title: "a", starts_at: 3.days.ago, source: "manual", ticket_sales_cents: 100)
    high = Show.create!(title: "b", starts_at: 4.days.ago, source: "manual", ticket_sales_cents: 900)
    Show.create!(title: "c", starts_at: 5.days.ago, source: "manual", ticket_sales_cents: 5_000, status: "canceled")
    Show.create!(title: "d", starts_at: 5.days.from_now, source: "manual", ticket_sales_cents: 5_000)
    assert_equal [ high, low ], Show.top_ticket_sales.to_a
  end
end
