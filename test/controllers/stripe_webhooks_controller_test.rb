require "test_helper"

class StripeWebhooksControllerTest < ActionDispatch::IntegrationTest
  SHIPPING_DETAILS = {
    "name" => "Test Fan",
    "address" => {
      "line1" => "123 Main St",
      "line2" => nil,
      "city" => "Nashville",
      "state" => "TN",
      "postal_code" => "37201",
      "country" => "US"
    }
  }.freeze

  # Current API versions nest shipping under collected_information; pass
  # legacy_shipping: true to build a pre-2025-03-31.basil payload instead.
  def fake_event(type:, stripe_session_id:, payment_status: "paid", event_id: nil, legacy_shipping: false)
    event_id ||= "evt_test_#{SecureRandom.hex(6)}"
    session = {
      "id" => stripe_session_id,
      "object" => "checkout.session",
      "payment_status" => payment_status,
      "payment_intent" => "pi_test_#{SecureRandom.hex(4)}",
      "amount_total" => 3300,
      "total_details" => { "amount_shipping" => 800 },
      "customer_details" => { "email" => "fan@example.com", "name" => "Test Fan" }
    }
    if legacy_shipping
      session["shipping_details"] = SHIPPING_DETAILS
    else
      session["collected_information"] = { "shipping_details" => SHIPPING_DETAILS }
    end

    Stripe::Event.construct_from({
      "id" => event_id,
      "type" => type,
      "data" => { "object" => session }
    })
  end

  def post_webhook(event)
    Stripe::Webhook.stub(:construct_event, event) do
      post stripe_webhook_path, headers: { "Stripe-Signature" => "t=1,v1=fake" }
    end
  end

  # — happy path —

  test "marks order paid on checkout.session.completed" do
    order = orders(:one)
    order.update!(status: "pending")
    event = fake_event(type: "checkout.session.completed", stripe_session_id: order.stripe_checkout_session_id)

    post_webhook(event)

    assert_response :ok
    order.reload
    assert_equal "paid", order.status
    assert_equal "fan@example.com", order.buyer_email
    assert_equal 3300, order.total_cents
    assert_equal 800, order.shipping_cents
    assert_equal "Test Fan", order.shipping_name
    assert_equal "123 Main St", order.shipping_address1
    assert_equal "Nashville", order.shipping_city
    assert_equal "TN", order.shipping_state
    assert_equal "37201", order.shipping_zip
    assert_equal "US", order.shipping_country
  end

  test "still reads shipping from legacy top-level shipping_details payload" do
    order = orders(:one)
    order.update!(status: "pending")
    event = fake_event(type: "checkout.session.completed",
                       stripe_session_id: order.stripe_checkout_session_id,
                       legacy_shipping: true)

    post_webhook(event)

    order.reload
    assert_equal "paid", order.status
    assert_equal "123 Main St", order.shipping_address1
    assert_equal "Nashville", order.shipping_city
  end

  test "decrements variant stock when fulfilling" do
    order = orders(:one)
    order.update!(status: "pending")
    original_stock = variants(:shirt_small).stock_quantity
    event = fake_event(type: "checkout.session.completed", stripe_session_id: order.stripe_checkout_session_id)

    post_webhook(event)

    expected = [ original_stock - order_items(:shirt_in_paid_order).quantity, 0 ].max
    assert_equal expected, variants(:shirt_small).reload.stock_quantity
  end

  test "floors stock at zero when quantity exceeds available stock" do
    order = orders(:one)
    order.update!(status: "pending")
    variants(:shirt_small).update!(stock_quantity: 0)
    event = fake_event(type: "checkout.session.completed", stripe_session_id: order.stripe_checkout_session_id)

    post_webhook(event)

    assert_equal 0, variants(:shirt_small).reload.stock_quantity
    assert_equal "paid", orders(:one).reload.status
  end

  test "is idempotent — second event with same ID is a no-op" do
    order = orders(:one)
    order.update!(status: "pending")
    shared_event_id = "evt_test_idempotency_abc"
    event = fake_event(
      type: "checkout.session.completed",
      stripe_session_id: order.stripe_checkout_session_id,
      event_id: shared_event_id
    )

    post_webhook(event)
    assert_response :ok
    assert_equal "paid", order.reload.status

    # Second POST — order is now paid, early return fires before StripeEvent.create!
    post_webhook(event)
    assert_response :ok
    assert_equal 1, StripeEvent.where(stripe_event_id: shared_event_id).count
  end

  test "ignores completed session with unpaid status" do
    order = orders(:one)
    order.update!(status: "pending")
    event = fake_event(
      type: "checkout.session.completed",
      stripe_session_id: order.stripe_checkout_session_id,
      payment_status: "unpaid"
    )

    post_webhook(event)

    assert_response :ok
    assert_equal "pending", order.reload.status
  end

  test "cancels pending order on checkout.session.expired" do
    order = orders(:one)
    order.update!(status: "pending")
    event = fake_event(type: "checkout.session.expired", stripe_session_id: order.stripe_checkout_session_id)

    post_webhook(event)

    assert_response :ok
    assert_equal "canceled", order.reload.status
  end

  test "does not cancel a paid order on checkout.session.expired" do
    order = orders(:one)
    assert_equal "paid", order.status
    event = fake_event(type: "checkout.session.expired", stripe_session_id: order.stripe_checkout_session_id)

    post_webhook(event)

    assert_response :ok
    assert_equal "paid", order.reload.status
  end

  test "returns 200 and skips fulfillment for unknown session id" do
    event = fake_event(type: "checkout.session.completed", stripe_session_id: "cs_unknown_xyz")

    post_webhook(event)

    assert_response :ok
  end

  # — error handling —

  test "returns 400 for invalid signature" do
    Stripe::Webhook.stub(:construct_event, ->(*) { raise Stripe::SignatureVerificationError.new("bad", "hdr") }) do
      post stripe_webhook_path, headers: { "Stripe-Signature" => "bad" }
    end
    assert_response :bad_request
  end

  test "returns 400 for malformed JSON" do
    Stripe::Webhook.stub(:construct_event, ->(*) { raise JSON::ParserError, "bad json" }) do
      post stripe_webhook_path, headers: { "Stripe-Signature" => "t=1" }
    end
    assert_response :bad_request
  end

  test "returns 200 for unknown event types" do
    event = fake_event(type: "payment_intent.succeeded", stripe_session_id: "cs_irrelevant")

    post_webhook(event)

    assert_response :ok
  end
end
