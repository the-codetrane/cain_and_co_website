require "test_helper"

class Admin::OrdersControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:one)) }

  test "index requires authentication" do
    reset!
    get admin_orders_path
    assert_redirected_to new_session_path
  end

  test "index shows needs-fulfillment and recent orders" do
    get admin_orders_path
    assert_response :success
    assert_match orders(:one).buyer_name, response.body   # paid — needs fulfillment
    assert_match orders(:two).buyer_name, response.body   # fulfilled — recent
  end

  test "show renders order details and line items" do
    get admin_order_path(orders(:one))
    assert_response :success
    assert_match "Band Shirt", response.body
    assert_match orders(:one).buyer_email, response.body
  end

  test "fulfill transitions a paid order to fulfilled" do
    patch fulfill_admin_order_path(orders(:one))
    assert_redirected_to admin_order_path(orders(:one))
    assert_equal "fulfilled", orders(:one).reload.status
  end

  test "fulfill rejects non-paid orders" do
    patch fulfill_admin_order_path(orders(:two))   # already fulfilled
    assert_redirected_to admin_order_path(orders(:two))
    assert_match "Only paid orders", flash[:alert]
  end
end
