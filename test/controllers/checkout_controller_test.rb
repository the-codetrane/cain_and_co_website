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

  test "sends Stripe an unencoded {CHECKOUT_SESSION_ID} placeholder in return URLs" do
    post cart_cart_items_path, params: { variant_id: variants(:shirt_small).id }

    captured_params = nil
    Stripe::Checkout::Session.stub(:create, ->(params) { captured_params = params; mock_stripe_session }) do
      post checkout_path
    end

    # Route helpers percent-encode the braces to %7B...%7D, which Stripe will not
    # substitute -- the placeholder then reaches OrdersController#success verbatim
    # and fails its session_id check with a 404.
    %i[success_url cancel_url].each do |key|
      assert_includes captured_params[key], "session_id={CHECKOUT_SESSION_ID}",
        "#{key} must carry the literal placeholder for Stripe to substitute"
      assert_not_includes captured_params[key], "%7B",
        "#{key} must not percent-encode the placeholder braces"
    end
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

  test "quotes Stripe a shipping rate derived from cart weight" do
    post cart_cart_items_path, params: { variant_id: variants(:shirt_small).id, quantity: 2 }

    captured_params = nil
    Stripe::Checkout::Session.stub(:create, ->(params) { captured_params = params; mock_stripe_session }) do
      post checkout_path
    end

    expected = ShippingRate.new(2 * variants(:shirt_small).weight_oz).cents
    rate_data = captured_params[:shipping_options].sole[:shipping_rate_data]

    assert_equal expected, rate_data[:fixed_amount][:amount]
    assert_equal "usd", rate_data[:fixed_amount][:currency]
  end

  test "a heavier cart is quoted more shipping than a lighter one" do
    light = nil
    post cart_cart_items_path, params: { variant_id: variants(:shirt_small).id, quantity: 1 }
    Stripe::Checkout::Session.stub(:create, ->(params) { light = params; mock_stripe_session(id: "cs_test_light") }) do
      post checkout_path
    end

    heavy = nil
    post cart_cart_items_path, params: { variant_id: variants(:shirt_small).id, quantity: 8 }
    Stripe::Checkout::Session.stub(:create, ->(params) { heavy = params; mock_stripe_session(id: "cs_test_heavy") }) do
      post checkout_path
    end

    amount = ->(params) { params[:shipping_options].sole[:shipping_rate_data][:fixed_amount][:amount] }
    assert_operator amount.call(heavy), :>, amount.call(light)
  end

  test "records the quoted shipping on the pending order" do
    post cart_cart_items_path, params: { variant_id: variants(:shirt_small).id, quantity: 2 }

    Stripe::Checkout::Session.stub(:create, mock_stripe_session) do
      post checkout_path
    end

    order = Order.last
    expected_shipping = ShippingRate.new(2 * variants(:shirt_small).weight_oz).cents

    assert_equal expected_shipping, order.shipping_cents
    assert_equal order.subtotal_cents + expected_shipping, order.total_cents
  end
end
