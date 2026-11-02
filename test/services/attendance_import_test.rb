require "test_helper"

class AttendanceImportTest < ActiveSupport::TestCase
  setup do
    @csv = Tempfile.new([ "attendance", ".csv" ])
    @csv.write(<<~CSV)
      date,venue,attendance,ticket_sales,title
      2025-04-26,Rök Bar,25,,
      2025-02-01,Shaw's,40,1000,Cain & Co. at Shaw's (with July Figher)
    CSV
    @csv.flush
  end

  teardown { @csv.close! }

  def import(**opts) = AttendanceImport.new(path: @csv.path, **opts).call

  test "matches a synced show by local date and loose venue name, across the UTC day boundary" do
    # 8pm Central on Apr 26 is 01:00 UTC on Apr 27.
    synced = Show.create!(title: "Cain & Co. at Rok Bar", venue_name: "The Rok Bar",
                          starts_at: Time.utc(2025, 4, 27, 1), source: "bandsintown", bandsintown_id: "rok-1")
    results = import
    assert_equal 25, synced.reload.attendance
    assert_equal :updated, results.first.action
  end

  test "creates a manual show when nothing matches, using the row's title" do
    assert_difference -> { Show.manual.count }, 2 do
      import
    end
    shaws = Show.find_by!(venue_name: "Shaw's")
    assert_equal "Cain & Co. at Shaw's (with July Figher)", shaws.title
    assert_equal 40, shaws.attendance
    assert_equal 100_000, shaws.ticket_sales_cents
    assert_equal Date.new(2025, 2, 1), shaws.starts_at.in_time_zone("America/Chicago").to_date
    assert_equal "Cain & Co. at Rök Bar", Show.find_by!(venue_name: "Rök Bar").title
  end

  test "a blank ticket-sales cell never clears a figure entered in admin" do
    synced = Show.create!(title: "Rok", venue_name: "Rök Bar", starts_at: Time.utc(2025, 4, 27, 1),
                          source: "bandsintown", bandsintown_id: "rok-2", ticket_sales_cents: 30_000)
    import
    assert_equal 30_000, synced.reload.ticket_sales_cents
  end

  test "is idempotent" do
    import
    assert_no_difference -> { Show.count } do
      assert_equal %i[unchanged unchanged], import.map(&:action)
    end
  end

  test "dry run writes nothing" do
    assert_no_difference -> { Show.count } do
      assert_equal %i[created created], import(dry_run: true).map(&:action)
    end
  end

  test "ignores canceled shows and different venues on the same date" do
    Show.create!(title: "x", venue_name: "Rök Bar", starts_at: Time.utc(2025, 4, 27, 1),
                 source: "manual", status: "canceled")
    Show.create!(title: "y", venue_name: "Turf Club", starts_at: Time.utc(2025, 4, 27, 1), source: "manual")
    assert_equal :created, import.first.action
  end

  test "venue_key normalizes accents, articles, punctuation and parentheticals" do
    assert_equal "rokbar", AttendanceImport.venue_key("The Rök Bar (Upstairs)")
    assert_equal AttendanceImport.venue_key("KJ's Hideaway"), AttendanceImport.venue_key("KJs Hideaway")
  end
end
