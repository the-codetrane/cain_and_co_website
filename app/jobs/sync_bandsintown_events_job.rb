# Pulls the band's events from Bandsintown into the local Show table.
#
# - Upserts upcoming + past events by bandsintown_id (never touches manual shows).
# - Reconciles the UPCOMING window: any synced upcoming show that Bandsintown no
#   longer returns is marked canceled (it was pulled/postponed). Past shows are
#   left untouched so the archive is stable.
#
# Runs on a schedule (see config/recurring.yml) and on demand from the admin.
class SyncBandsintownEventsJob < ApplicationJob
  queue_as :default

  # Transient network errors: let Active Job retry with backoff.
  retry_on BandsintownClient::Error, wait: :polynomially_longer, attempts: 3

  def perform(client: BandsintownClient.new)
    unless client.configured?
      Rails.logger.info("[Bandsintown] skipping sync — not configured")
      return
    end

    new_upcoming = []
    seen_ids = []
    %w[upcoming past].each do |date|
      client.events(date: date).each do |payload|
        next if payload["id"].blank?
        show = Show.from_bandsintown(payload)
        seen_ids << show.bandsintown_id
        new_upcoming << show if show.previously_new_record? && date == "upcoming"
      end
    end

    canceled = reconcile_upcoming(seen_ids)
    Rails.logger.info("[Bandsintown] synced #{seen_ids.size} events, canceled #{canceled} stale upcoming")

    if new_upcoming.any? && PushSubscription.exists?
      first = new_upcoming.first
      BroadcastPushJob.perform_later(
        title: "New show announced!",
        body: [ first.title, first.location ].compact_blank.join(" – "),
        url: "/shows"
      )
    end
  end

  private

  # Mark synced upcoming shows that no longer appear in the feed as canceled.
  def reconcile_upcoming(seen_ids)
    Show.bandsintown.upcoming.where.not(bandsintown_id: seen_ids)
        .update_all(status: "canceled", updated_at: Time.current)
  end
end
