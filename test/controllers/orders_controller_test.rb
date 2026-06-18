require "test_helper"

class OrdersControllerTest < ActionDispatch::IntegrationTest
  test "success renders when session_id matches" do
    order = orders(:one)
    get order_success_path(order, session_id: order.stripe_checkout_session_id)
    assert_response :success
  end

  test "success returns 404 when session_id is wrong" do
    order = orders(:one)
    get order_success_path(order, session_id: "cs_wrong")
    assert_response :not_found
  end

  test "success returns 404 when session_id is missing" do
    order = orders(:one)
    get order_success_path(order)
    assert_response :not_found
  end

  test "cancel renders when session_id matches" do
    order = orders(:one)
    get order_cancel_path(order, session_id: order.stripe_checkout_session_id)
    assert_response :success
  end

  test "cancel returns 404 when session_id is wrong" do
    order = orders(:one)
    get order_cancel_path(order, session_id: "cs_wrong")
    assert_response :not_found
  end
end
