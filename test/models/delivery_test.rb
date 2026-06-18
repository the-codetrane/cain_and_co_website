require "test_helper"

class DeliveryTest < ActiveSupport::TestCase
  setup do
    @delivery = Delivery.create!(newsletter: newsletters(:draft_issue), subscriber: subscribers(:confirmed_fan))
  end

  test "starts pending" do
    assert @delivery.pending?
  end

  test "mark_sent! sets status and timestamp" do
    @delivery.mark_sent!
    assert @delivery.sent?
    assert_not_nil @delivery.sent_at
  end

  test "mark_failed! records a truncated error" do
    @delivery.mark_failed!("x" * 2000)
    assert @delivery.failed?
    assert_equal 1000, @delivery.error.length
  end

  test "sent_today scope only includes today's sends" do
    @delivery.mark_sent!
    old = Delivery.create!(newsletter: newsletters(:draft_issue), subscriber: subscribers(:unsubscribed_fan),
                           status: :sent, sent_at: 2.days.ago)
    assert_includes Delivery.sent_today, @delivery
    assert_not_includes Delivery.sent_today, old
  end

  test "unique per newsletter and subscriber" do
    dup = Delivery.new(newsletter: newsletters(:draft_issue), subscriber: subscribers(:confirmed_fan))
    assert_raises(ActiveRecord::RecordNotUnique) { dup.save!(validate: false) }
  end
end
