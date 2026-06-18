require "test_helper"

class SubscriberTest < ActiveSupport::TestCase
  test "normalizes email" do
    s = Subscriber.create!(email: "  Fan@Example.COM ")
    assert_equal "fan@example.com", s.email
  end

  test "rejects invalid and duplicate emails" do
    assert_not Subscriber.new(email: "nope").valid?
    dup = Subscriber.new(email: subscribers(:confirmed_fan).email.upcase)
    assert_not dup.valid?
  end

  test "status reflects lifecycle" do
    assert_equal "confirmed", subscribers(:confirmed_fan).status
    assert_equal "unconfirmed", subscribers(:unconfirmed_fan).status
    assert_equal "unsubscribed", subscribers(:unsubscribed_fan).status
  end

  test "scopes partition the list" do
    assert_includes Subscriber.confirmed, subscribers(:confirmed_fan)
    assert_includes Subscriber.unconfirmed, subscribers(:unconfirmed_fan)
    assert_includes Subscriber.unsubscribed, subscribers(:unsubscribed_fan)
    assert_not_includes Subscriber.confirmed, subscribers(:unsubscribed_fan)
  end

  test "confirm! sets confirmed_at and is idempotent" do
    s = subscribers(:unconfirmed_fan)
    s.confirm!
    assert s.confirmed?
    assert_no_changes -> { s.reload.confirmed_at } do
      s.confirm!
    end
  end

  test "unsubscribe! marks unsubscribed and excludes from confirmed" do
    s = subscribers(:confirmed_fan)
    s.unsubscribe!
    assert s.unsubscribed?
    assert_not_includes Subscriber.confirmed, s
  end

  test "confirmation token expires, unsubscribe token does not" do
    s = subscribers(:confirmed_fan)
    c = s.generate_token_for(:confirmation)
    assert_equal s, Subscriber.find_by_token_for(:confirmation, c)

    u = s.generate_token_for(:unsubscribe)
    travel 3.years do
      assert_equal s, Subscriber.find_by_token_for(:unsubscribe, u)
    end
  end
end
