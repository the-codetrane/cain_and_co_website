require "test_helper"

class PushSubscriptionTest < ActiveSupport::TestCase
  test "valid with required fields" do
    sub = PushSubscription.new(endpoint: "https://push.example.com/new", p256dh_key: "key123", auth_key: "auth123")
    assert sub.valid?
  end

  test "invalid without endpoint" do
    sub = PushSubscription.new(p256dh_key: "key", auth_key: "auth")
    assert_not sub.valid?
    assert_includes sub.errors[:endpoint], "can't be blank"
  end

  test "invalid without p256dh_key" do
    sub = PushSubscription.new(endpoint: "https://push.example.com/x", auth_key: "auth")
    assert_not sub.valid?
    assert_includes sub.errors[:p256dh_key], "can't be blank"
  end

  test "invalid without auth_key" do
    sub = PushSubscription.new(endpoint: "https://push.example.com/y", p256dh_key: "key")
    assert_not sub.valid?
    assert_includes sub.errors[:auth_key], "can't be blank"
  end

  test "endpoint must be unique" do
    PushSubscription.create!(endpoint: "https://push.example.com/existing", p256dh_key: "k1", auth_key: "a1")
    dup = PushSubscription.new(endpoint: "https://push.example.com/existing", p256dh_key: "k2", auth_key: "a2")
    assert_not dup.valid?
    assert_includes dup.errors[:endpoint], "has already been taken"
  end
end
