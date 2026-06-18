# Delivers one newsletter to one subscriber. Runs on the single-thread
# :newsletters queue, so deliveries are serialized and the daily-cap count it
# reads is consistent.
#
# Idempotent: it only acts on a still-pending delivery and transitions that row
# to a terminal state, so a retried or duplicate enqueue can't double-send.
class DeliverNewsletterJob < ApplicationJob
  queue_as :newsletters

  def perform(delivery_id)
    delivery = Delivery.find_by(id: delivery_id)
    return unless delivery&.pending?

    # Over the daily cap — leave pending; DrainNewsletterDeliveriesJob resumes
    # it once the count rolls over to the next day.
    return if NewsletterDispatch.remaining_today.zero?

    subscriber = delivery.subscriber
    unless subscriber.confirmed?
      # Unsubscribed/unconfirmed since the send started — terminal, don't retry.
      delivery.mark_failed!("recipient is no longer subscribed")
      return NewsletterDispatch.finalize(delivery.newsletter)
    end

    deliver(delivery, subscriber)
    NewsletterDispatch.finalize(delivery.newsletter)
  end

  private

  def deliver(delivery, subscriber)
    NewsletterMailer.with(newsletter: delivery.newsletter, subscriber: subscriber).issue.deliver_now
    delivery.mark_sent!
  rescue StandardError => e
    # Record the failure per-recipient rather than failing the whole send; the
    # admin can see and re-send failures. (One bad address shouldn't block the list.)
    delivery.mark_failed!(e.message)
    Rails.logger.error("[Newsletter] delivery ##{delivery.id} failed: #{e.class}: #{e.message}")
  end
end
