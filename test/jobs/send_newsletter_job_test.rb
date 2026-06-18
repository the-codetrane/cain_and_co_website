require "test_helper"

class SendNewsletterJobTest < ActiveJob::TestCase
  test "builds deliveries and fans out one delivery job per active subscriber" do
    newsletter = newsletters(:draft_issue)
    newsletter.update!(status: :sending)

    assert_enqueued_jobs Subscriber.active.count, only: DeliverNewsletterJob do
      SendNewsletterJob.perform_now(newsletter.id)
    end
    assert_equal Subscriber.active.count, newsletter.deliveries.count
  end

  test "promotes a scheduled newsletter to sending" do
    newsletter = newsletters(:scheduled_issue)
    SendNewsletterJob.perform_now(newsletter.id)
    assert newsletter.reload.sending?
  end

  test "ignores a draft (stale enqueue)" do
    newsletter = newsletters(:draft_issue)
    assert_no_enqueued_jobs only: DeliverNewsletterJob do
      SendNewsletterJob.perform_now(newsletter.id)
    end
    assert newsletter.reload.draft?
    assert_equal 0, newsletter.deliveries.count
  end

  test "ignores an already-sent newsletter" do
    newsletter = newsletters(:sent_issue)
    assert_no_enqueued_jobs only: DeliverNewsletterJob do
      SendNewsletterJob.perform_now(newsletter.id)
    end
  end

  test "ignores a missing newsletter" do
    assert_nothing_raised { SendNewsletterJob.perform_now(-1) }
  end
end
