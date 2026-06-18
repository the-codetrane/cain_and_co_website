require "test_helper"

class DrainNewsletterDeliveriesJobTest < ActiveJob::TestCase
  test "re-dispatches sending newsletters that still have pending deliveries" do
    newsletter = newsletters(:draft_issue)
    newsletter.update!(status: :sending)
    Delivery.create!(newsletter: newsletter, subscriber: subscribers(:confirmed_fan))

    assert_enqueued_jobs 1, only: DeliverNewsletterJob do
      DrainNewsletterDeliveriesJob.perform_now
    end
  end

  test "finalizes a sending newsletter with no pending deliveries" do
    newsletter = newsletters(:draft_issue)
    newsletter.update!(status: :sending)
    Delivery.create!(newsletter: newsletter, subscriber: subscribers(:confirmed_fan), status: :sent, sent_at: Time.current)

    DrainNewsletterDeliveriesJob.perform_now
    assert newsletter.reload.sent?
  end

  test "leaves draft and sent newsletters alone" do
    assert_no_enqueued_jobs only: DeliverNewsletterJob do
      DrainNewsletterDeliveriesJob.perform_now
    end
  end
end
