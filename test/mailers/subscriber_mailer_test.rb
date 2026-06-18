require "test_helper"

class SubscriberMailerTest < ActionMailer::TestCase
  test "confirmation" do
    subscriber = subscribers(:unconfirmed_fan)
    mail = SubscriberMailer.with(subscriber: subscriber).confirmation

    assert_equal "Confirm your Cain & Co. newsletter subscription", mail.subject
    assert_equal [ subscriber.email ], mail.to
    assert_match "/newsletter/confirm/", mail.body.encoded
  end
end
