require "test_helper"

class PushSubscriptionsControllerTest < ActionDispatch::IntegrationTest
  def valid_params
    {
      push_subscription: {
        endpoint: "https://push.example.com/sub/unique123",
        p256dh_key: "BNcRdreALRFXTkOOUHK1EtK2wtaz5Ry4YfYCA_0QTpQt",
        auth_key: "tBHItJI5svbpez7KI4CCXg",
        user_agent: "Mozilla/5.0 (Test)"
      }
    }
  end

  test "creates a push subscription" do
    assert_difference("PushSubscription.count", 1) do
      post push_subscriptions_path, params: valid_params, as: :json
    end
    assert_response :created
  end

  test "upserts on duplicate endpoint — refreshes keys rather than erroring" do
    post push_subscriptions_path, params: valid_params, as: :json
    assert_response :created
    assert_equal 1, PushSubscription.where(endpoint: valid_params.dig(:push_subscription, :endpoint)).count

    updated = valid_params.deep_merge(push_subscription: { p256dh_key: "rotated_key" })
    assert_no_difference("PushSubscription.count") do
      post push_subscriptions_path, params: updated, as: :json
    end
    assert_response :created
    assert_equal "rotated_key", PushSubscription.find_by(endpoint: valid_params.dig(:push_subscription, :endpoint)).p256dh_key
  end

  test "returns bad request when push_subscription param is missing" do
    post push_subscriptions_path, params: {}, as: :json
    assert_response :bad_request
  end
end
