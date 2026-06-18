# Starts (or, when scheduled, fires) a newsletter send. Snapshots the recipient
# list into Delivery rows, then hands off to NewsletterDispatch to fan out one
# DeliverNewsletterJob per recipient (throttled by the :newsletters queue and
# the daily cap). Enqueued immediately for "send now" or with `wait_until:` for
# a scheduled send.
class SendNewsletterJob < ApplicationJob
  queue_as :default

  def perform(newsletter_id)
    newsletter = Newsletter.find_by(id: newsletter_id)
    return unless newsletter
    # Only proceed from scheduled (timer fired) or sending (manual send / retry).
    # A draft or already-sent newsletter is a stale enqueue — ignore it.
    return unless newsletter.scheduled? || newsletter.sending?

    newsletter.update!(status: :sending) unless newsletter.sending?
    newsletter.build_deliveries!
    NewsletterDispatch.dispatch(newsletter)
  end
end
