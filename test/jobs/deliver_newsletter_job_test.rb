require "test_helper"

class DeliverNewsletterJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    @newsletter = newsletters(:draft_issue)
    @newsletter.update!(status: :sending)
    @delivery = Delivery.create!(newsletter: @newsletter, subscriber: subscribers(:confirmed_fan))
  end

  test "delivers the email and marks the delivery sent" do
    assert_emails 1 do
      perform_enqueued_jobs { DeliverNewsletterJob.perform_now(@delivery.id) }
    end
    assert @delivery.reload.sent?
    assert_not_nil @delivery.sent_at
  end

  test "finalizes the newsletter once the last delivery is sent" do
    DeliverNewsletterJob.perform_now(@delivery.id)
    assert @newsletter.reload.sent?
    assert_not_nil @newsletter.sent_at
  end

  test "is idempotent — does not re-send an already-sent delivery" do
    @delivery.mark_sent!
    assert_no_emails { DeliverNewsletterJob.perform_now(@delivery.id) }
  end

  test "marks delivery failed for a recipient who is no longer subscribed" do
    @delivery.update!(subscriber: subscribers(:unsubscribed_fan))
    assert_no_emails { DeliverNewsletterJob.perform_now(@delivery.id) }
    assert @delivery.reload.failed?
    assert_match(/no longer subscribed/, @delivery.error)
  end

  test "respects the daily cap by leaving the delivery pending" do
    original = ENV["NEWSLETTER_DAILY_CAP"]
    ENV["NEWSLETTER_DAILY_CAP"] = "0"
    assert_no_emails { DeliverNewsletterJob.perform_now(@delivery.id) }
    assert @delivery.reload.pending?
  ensure
    ENV["NEWSLETTER_DAILY_CAP"] = original
  end

  # A delivery method that always blows up, to exercise the per-recipient rescue.
  class RaisingDelivery
    def initialize(*) = nil
    def deliver!(*) = raise(StandardError, "smtp down")
  end

  test "records a failure when delivery raises" do
    ActionMailer::Base.add_delivery_method(:raising, RaisingDelivery)
    original = ActionMailer::Base.delivery_method
    ActionMailer::Base.delivery_method = :raising

    DeliverNewsletterJob.perform_now(@delivery.id)
    assert @delivery.reload.failed?
    assert_match(/smtp down/, @delivery.error)
  ensure
    ActionMailer::Base.delivery_method = original
  end
end
