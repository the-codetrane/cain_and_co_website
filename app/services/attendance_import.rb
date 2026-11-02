require "csv"

# One-off seed: applies hand-kept headcounts and ticket sales
# (db/data/gig_history_attendance.csv, exported from the band's "Gig History" sheet)
# to Shows. After this runs, the database is the source of truth; keep new numbers
# up to date in Admin › Shows, not in the CSV.
#
# Each row is matched to an existing active show on the same local (Central) date
# whose venue name matches loosely ("The Garage" == "Garage", "Rök Bar" == "Rok Bar").
# Rows with no match become manual shows so the EPK history is complete.
# Idempotent: re-running updates the same shows and creates nothing new.
#
#   bin/rails shows:import_attendance DRY_RUN=1   # print the plan only
#   bin/rails shows:import_attendance             # apply it
class AttendanceImport
  DEFAULT_PATH = Rails.root.join("db/data/gig_history_attendance.csv")
  ZONE = "America/Chicago"
  # Bandsintown stores UTC; an 8pm Central start is the next day in UTC, so
  # compare local dates and allow ±1 day for shows entered with odd times.
  DATE_SLOP = 1.day
  DEFAULT_START_HOUR = 20

  Result = Data.define(:action, :show, :row)

  def initialize(path: DEFAULT_PATH, dry_run: false)
    @path = path
    @dry_run = dry_run
  end

  def call
    CSV.foreach(@path, headers: true).map { |row| apply(row) }
  end

  private

  def apply(row)
    date = Date.iso8601(row["date"])
    stats = { attendance: Integer(row["attendance"]) }
    # Only touch ticket sales when the sheet has a figure, so a blank cell never
    # wipes a number entered in admin.
    stats[:ticket_sales_cents] = Integer(row["ticket_sales"]) * 100 if row["ticket_sales"].present?
    show = find_match(date, row["venue"])

    if show
      show.assign_attributes(stats)
      action = show.changed? ? :updated : :unchanged
      show.save! unless @dry_run || action == :unchanged
    else
      action = :created
      show = Show.new(
        source: "manual", status: "active",
        title: row["title"].presence || "Cain & Co. at #{row["venue"]}",
        venue_name: row["venue"],
        starts_at: Time.find_zone!(ZONE).local(date.year, date.month, date.day, DEFAULT_START_HOUR),
        **stats
      )
      show.save! unless @dry_run
    end

    Result.new(action:, show:, row:)
  end

  def find_match(date, venue)
    zone = Time.find_zone!(ZONE)
    window = zone.local(date.year, date.month, date.day).then { |d| (d - DATE_SLOP)..(d + DATE_SLOP).end_of_day }
    candidates = Show.active.where(starts_at: window).to_a
    candidates.select! { |s| self.class.venue_key(s.venue_name) == self.class.venue_key(venue) }
    # Prefer the exact local date when the slop window catches more than one.
    candidates.min_by { |s| (s.starts_at.in_time_zone(zone).to_date - date).abs }
  end

  # "The Rök Bar (Upstairs)" -> "rokbar"
  def self.venue_key(name)
    I18n.transliterate(name.to_s).downcase
        .sub(/\(.*?\)/, "").sub(/\Athe\s+/, "")
        .gsub(/[^a-z0-9]/, "")
  end
end
