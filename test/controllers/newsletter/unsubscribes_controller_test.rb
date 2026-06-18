require "test_helper"

class Newsletter::UnsubscribesControllerTest < ActionDispatch::IntegrationTest
  test "show renders a confirmation page for a valid token" do
    s = subscribers(:confirmed_fan)
    get newsletter_unsubscribe_path(token: s.generate_token_for(:unsubscribe))
    assert_response :success
    assert_match s.email, response.body
  end

  test "show with an invalid token is rejected" do
    get newsletter_unsubscribe_path(token: "garbage")
    assert_response :unprocessable_entity
  end

  test "post unsubscribes the subscriber" do
    s = subscribers(:confirmed_fan)
    post newsletter_unsubscribe_path(token: s.generate_token_for(:unsubscribe))
    assert_response :success
    assert s.reload.unsubscribed?
  end

  test "one-click POST works without a CSRF token" do
    # Simulate a mailbox provider's List-Unsubscribe-Post with forgery protection on.
    s = subscribers(:confirmed_fan)
    token = s.generate_token_for(:unsubscribe)
    with_forgery_protection do
      post newsletter_unsubscribe_path(token: token)
    end
    assert_response :success
    assert s.reload.unsubscribed?
  end

  private

  def with_forgery_protection
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = original
  end
end
