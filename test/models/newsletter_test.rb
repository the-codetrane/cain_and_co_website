require "test_helper"

class NewsletterTest < ActiveSupport::TestCase
  test "requires a subject" do
    newsletter = Newsletter.new
    assert_not newsletter.valid?
    assert_includes newsletter.errors[:subject], "can't be blank"
  end

  test "body is optional while draft but required once leaving draft" do
    newsletter = Newsletter.new(subject: "Hi")
    assert newsletter.valid?, "a draft without a body should be valid"

    newsletter.status = :scheduled
    newsletter.scheduled_at = 1.day.from_now
    assert_not newsletter.valid?
    assert_includes newsletter.errors[:body], "can't be blank"
  end

  test "scheduled newsletter requires scheduled_at" do
    newsletter = newsletters(:draft_issue)
    newsletter.status = :scheduled
    assert_not newsletter.valid?
    assert_includes newsletter.errors[:scheduled_at], "can't be blank"
  end

  test "sendable? only while draft" do
    assert newsletters(:draft_issue).sendable?
    assert_not newsletters(:scheduled_issue).sendable?
    assert_not newsletters(:sent_issue).sendable?
  end

  test "build_deliveries! snapshots only active subscribers" do
    newsletter = newsletters(:draft_issue)
    assert_difference -> { newsletter.deliveries.count }, Subscriber.active.count do
      newsletter.build_deliveries!
    end
    recipients = newsletter.deliveries.map(&:subscriber)
    assert_includes recipients, subscribers(:confirmed_fan)
    assert_not_includes recipients, subscribers(:unconfirmed_fan)
    assert_not_includes recipients, subscribers(:unsubscribed_fan)
  end

  test "build_deliveries! is idempotent" do
    newsletter = newsletters(:draft_issue)
    newsletter.build_deliveries!
    assert_no_difference -> { newsletter.deliveries.count } do
      newsletter.build_deliveries!
    end
  end

  test "delivery_stats counts by status" do
    stats = newsletters(:sent_issue).delivery_stats
    assert_equal 2, stats[:total]
    assert_equal 1, stats[:sent]
    assert_equal 1, stats[:failed]
    assert_equal 0, stats[:pending]
  end
end
