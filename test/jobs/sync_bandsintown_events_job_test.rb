require "test_helper"

class SyncBandsintownEventsJobTest < ActiveJob::TestCase
  # Minimal stand-in for BandsintownClient.
  class FakeClient
    def initialize(upcoming: [], past: [], configured: true)
      @upcoming = upcoming
      @past = past
      @configured = configured
    end

    def configured? = @configured
    def events(date:) = date == "upcoming" ? @upcoming : @past
  end

  def event(id, when_at, title: "Show #{id}")
    {
      "id" => id, "title" => title, "datetime" => when_at.iso8601,
      "venue" => { "name" => "Venue #{id}", "city" => "City" },
      "url" => "https://bandsintown.com/e/#{id}"
    }
  end

  setup { Show.delete_all }

  test "no-ops when client is not configured" do
    assert_no_difference -> { Show.count } do
      SyncBandsintownEventsJob.new.perform(client: FakeClient.new(configured: false))
    end
  end

  test "upserts upcoming and past events" do
    client = FakeClient.new(
      upcoming: [ event("10", 5.days.from_now) ],
      past: [ event("9", 5.days.ago) ]
    )
    SyncBandsintownEventsJob.new.perform(client: client)

    assert_equal 2, Show.count
    assert_equal 1, Show.upcoming.count
    assert_equal 1, Show.past.count
  end

  test "cancels upcoming shows that disappear from the feed" do
    SyncBandsintownEventsJob.new.perform(
      client: FakeClient.new(upcoming: [ event("10", 5.days.from_now) ])
    )
    assert_equal "active", Show.find_by(bandsintown_id: "10").status

    # Next sync no longer returns event 10.
    SyncBandsintownEventsJob.new.perform(client: FakeClient.new(upcoming: []))
    assert_equal "canceled", Show.find_by(bandsintown_id: "10").status
  end

  test "does not touch manual shows" do
    manual = Show.create!(title: "Manual", starts_at: 3.days.from_now, source: "manual")
    SyncBandsintownEventsJob.new.perform(client: FakeClient.new(upcoming: []))
    assert_equal "active", manual.reload.status
  end
end
