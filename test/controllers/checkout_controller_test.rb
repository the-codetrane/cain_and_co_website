require "test_helper"

class CheckoutControllerTest < ActionDispatch::IntegrationTest
  def mock_stripe_session(id: "cs_test_mock_123")
    OpenStruct.new(
      id: id,
      url: "https://checkout.stripe.com/pay/#{id}"
    )
  end

  test "redirects to cart when cart is empty" do
    post checkout_path
    assert_redirected_to cart_path
    assert_equal "Your cart is empty.", flash[:alert]
  end

  test "creates pending order and redirects to Stripe" do
    post cart_cart_items_path, params: { variant_id: variants(:shirt_small).id, quantity: 2 }

    stripe_session = mock_stripe_session

    assert_difference -> { Order.count }, 1 do
      assert_difference -> { OrderItem.count }, 1 do
        Stripe::Checkout::Session.stub(:create, stripe_session) do
          post checkout_path
        end
      end
    end

    assert_response :redirect
    assert_redirected_to stripe_session.url

    order = Order.last
    assert_equal "pending", order.status
    assert_equal "cs_test_mock_123", order.stripe_checkout_session_id
    assert_equal 1, order.order_items.count
    assert_equal 2 * variants(:shirt_small).price_cents, order.subtotal_cents
    assert_equal variants(:shirt_small).display_name, order.order_items.first.variant_name
  end

  test "uses DB prices for line items, not client-submitted values" do
    post cart_cart_items_path, params: { variant_id: variants(:shirt_small).id }

    captured_params = nil
    Stripe::Checkout::Session.stub(:create, ->(params) { captured_params = params; mock_stripe_session }) do
      post checkout_path
    end

    line_item = captured_params[:line_items].first
    assert_equal variants(:shirt_small).price_cents, line_item[:price_data][:unit_amount]
  end

  test "destroys pending order if Stripe session creation fails" do
    post cart_cart_items_path, params: { variant_id: variants(:shirt_small).id }

    assert_no_difference -> { Order.count } do
      Stripe::Checkout::Session.stub(:create, ->(_) { raise Stripe::StripeError, "api error" }) do
        post checkout_path
      end
    end

    assert_redirected_to cart_path
    assert_match "Something went wrong", flash[:alert]
  end
end
