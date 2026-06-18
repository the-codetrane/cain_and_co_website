require "test_helper"

class Newsletter::SubscriptionsControllerTest < ActionDispatch::IntegrationTest
  test "subscribing creates an unconfirmed subscriber and sends confirmation" do
    assert_difference -> { Subscriber.count }, 1 do
      assert_enqueued_emails 1 do
        post newsletter_subscribe_path, params: { subscriber: { email: "New@Fan.com" } }
      end
    end
    subscriber = Subscriber.find_by(email: "new@fan.com")
    assert_equal "unconfirmed", subscriber.status
    assert_redirected_to root_path(anchor: "newsletter")
  end

  test "invalid email does not create a subscriber" do
    assert_no_difference -> { Subscriber.count } do
      post newsletter_subscribe_path, params: { subscriber: { email: "not-an-email" } }
    end
    assert_redirected_to root_path(anchor: "newsletter")
    assert flash[:alert].present?
  end

  test "re-subscribing an unsubscribed address reactivates and re-confirms" do
    gone = subscribers(:unsubscribed_fan)
    assert_no_difference -> { Subscriber.count } do
      assert_enqueued_emails 1 do
        post newsletter_subscribe_path, params: { subscriber: { email: gone.email } }
      end
    end
    assert_nil gone.reload.unsubscribed_at
  end

  test "confirm with a valid token confirms the subscriber" do
    s = subscribers(:unconfirmed_fan)
    get newsletter_confirm_path(token: s.generate_token_for(:confirmation))
    assert_response :success
    assert s.reload.confirmed?
  end

  test "confirm with an invalid token shows an error" do
    get newsletter_confirm_path(token: "garbage")
    assert_response :unprocessable_entity
  end
end
