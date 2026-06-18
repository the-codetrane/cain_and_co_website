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
end
