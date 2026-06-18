require "test_helper"

class StripeEventTest < ActiveSupport::TestCase
  test "stripe_event_id must be unique" do
    existing = stripe_events(:one)
    duplicate = StripeEvent.new(stripe_event_id: existing.stripe_event_id, processed_at: Time.current)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:stripe_event_id], "has already been taken"
  end

  test "stripe_event_id and processed_at are required" do
    event = StripeEvent.new
    assert_not event.valid?
    assert_includes event.errors[:stripe_event_id], "can't be blank"
    assert_includes event.errors[:processed_at], "can't be blank"
  end
end
