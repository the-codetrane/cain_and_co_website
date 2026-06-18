# Coordinates the per-recipient send pipeline and enforces the provider's daily
# send cap. Shared by SendNewsletterJob (initial send / scheduled fire) and
# DrainNewsletterDeliveriesJob (resume after the cap resets or a job fails).
#
# Two independent throttles protect deliverability:
#   * the single-thread :newsletters queue serializes SMTP connections, and
#   * the daily cap here bounds total volume (free Gmail 500/day, Workspace 2,000).
module NewsletterDispatch
  module_function

  # Stay under the hard provider cap with headroom for transactional mail
  # (confirmations, password resets) sharing the same mailbox.
  DEFAULT_DAILY_CAP = 450

  def daily_cap
    ENV.fetch("NEWSLETTER_DAILY_CAP", DEFAULT_DAILY_CAP).to_i
  end

  # How many more newsletter emails we may send today (app time zone).
  def remaining_today
    [ daily_cap - Delivery.sent_today.count, 0 ].max
  end

  # Enqueue per-recipient delivery jobs for this newsletter, up to today's
  # remaining quota. Safe to call repeatedly: DeliverNewsletterJob ignores any
  # delivery that isn't still pending, so an over-enqueue just no-ops.
  def dispatch(newsletter)
    return finalize(newsletter) unless newsletter.deliveries.pending.exists?

    limit = remaining_today
    return if limit.zero?

    newsletter.deliveries.pending.limit(limit).pluck(:id).each do |delivery_id|
      DeliverNewsletterJob.perform_later(delivery_id)
    end
  end

  # Mark the newsletter sent once every recipient has a terminal delivery.
  def finalize(newsletter)
    return false unless newsletter.sending?
    return false if newsletter.deliveries.pending.exists?

    newsletter.update!(status: :sent, sent_at: Time.current)
    true
  end
end
