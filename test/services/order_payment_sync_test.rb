require "test_helper"

class OrderPaymentSyncTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

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

  # Shaped like a session fetched with Stripe::Checkout::Session.retrieve, which is
  # what the reconciliation task passes in.
  def retrieved_session(order, payment_status: "paid", status: "complete", payment_intent: "pi_test_reconciled")
    Stripe::Checkout::Session.construct_from({
      "id" => order.stripe_checkout_session_id,
      "object" => "checkout.session",
      "status" => status,
      "payment_status" => payment_status,
      "payment_intent" => payment_intent,
      "amount_total" => 3300,
      "total_details" => { "amount_shipping" => 800 },
      "customer_details" => { "email" => "fan@example.com", "name" => "Test Fan" },
      "collected_information" => { "shipping_details" => SHIPPING_DETAILS }
    })
  end

  def pending_order
    orders(:one).tap { |order| order.update!(status: "pending") }
  end

  test "applies a paid session to a pending order" do
    order = pending_order

    assert OrderPaymentSync.apply_paid_session!(order, retrieved_session(order))

    order.reload
    assert_equal "paid", order.status
    assert_equal "pi_test_reconciled", order.stripe_payment_intent_id
    assert_equal "fan@example.com", order.buyer_email
    assert_equal 3300, order.total_cents
    assert_equal 800, order.shipping_cents
    assert_equal "123 Main St", order.shipping_address1
    assert_equal "37201", order.shipping_zip
  end

  test "decrements variant stock" do
    order = pending_order
    variant = order.order_items.first.variant

    assert_difference -> { variant.reload.stock_quantity }, -1 do
      OrderPaymentSync.apply_paid_session!(order, retrieved_session(order))
    end
  end

  test "emails a receipt, and skips it when asked" do
    order = pending_order
    assert_enqueued_emails 1 do
      OrderPaymentSync.apply_paid_session!(order, retrieved_session(order))
    end

    order.update!(status: "pending")
    assert_no_enqueued_emails do
      OrderPaymentSync.apply_paid_session!(order, retrieved_session(order), send_receipt: false)
    end
  end

  test "is a no-op for an order that is already paid or fulfilled" do
    assert_not OrderPaymentSync.apply_paid_session!(orders(:one), retrieved_session(orders(:one)))
    assert_not OrderPaymentSync.apply_paid_session!(orders(:two), retrieved_session(orders(:two)))
  end

  test "is a no-op for an unpaid session" do
    order = pending_order

    assert_not OrderPaymentSync.apply_paid_session!(
      order, retrieved_session(order, payment_status: "unpaid", status: "expired")
    )
    assert_equal "pending", order.reload.status
  end

  test "unwraps an expanded payment intent object" do
    order = pending_order
    intent = Stripe::PaymentIntent.construct_from({ "id" => "pi_expanded", "object" => "payment_intent" })

    OrderPaymentSync.apply_paid_session!(order, retrieved_session(order, payment_intent: intent))

    assert_equal "pi_expanded", order.reload.stripe_payment_intent_id
  end

  test "reads shipping from the legacy top-level field" do
    order = pending_order
    session = Stripe::Checkout::Session.construct_from({
      "id" => order.stripe_checkout_session_id,
      "object" => "checkout.session",
      "status" => "complete",
      "payment_status" => "paid",
      "payment_intent" => "pi_legacy",
      "amount_total" => 3300,
      "total_details" => { "amount_shipping" => 800 },
      "customer_details" => { "email" => "fan@example.com", "name" => "Test Fan" },
      "shipping_details" => SHIPPING_DETAILS
    })

    OrderPaymentSync.apply_paid_session!(order, session)

    assert_equal "Nashville", order.reload.shipping_city
  end
end
