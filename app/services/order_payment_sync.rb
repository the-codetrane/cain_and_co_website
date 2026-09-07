# Applies a paid Stripe Checkout Session to an Order.
#
# Two callers share this logic:
#   * StripeWebhooksController, on checkout.session.completed / async_payment_succeeded, and
#   * `rake orders:reconcile_pending`, which re-fetches the session from Stripe for
#     orders that are still pending because their webhook never arrived (or failed).
#
# Every entry point is idempotent: an order that is already paid or fulfilled is
# left untouched, so a replayed webhook and a reconciliation run cannot double
# decrement stock or send a second receipt.
module OrderPaymentSync
  module_function

  # Returns true when the order was transitioned to paid, false when the session
  # isn't paid or the order had already been reconciled.
  def apply_paid_session!(order, stripe_session, send_receipt: true)
    return false unless stripe_session.payment_status == "paid"
    return false if order.paid? || order.fulfilled?

    shipping = shipping_details_for(stripe_session)
    address  = shipping&.address

    order.update!(
      status: "paid",
      stripe_payment_intent_id: payment_intent_id(stripe_session),
      buyer_email: stripe_session.customer_details&.email,
      buyer_name: stripe_session.customer_details&.name,
      shipping_name: shipping&.name,
      shipping_address1: address&.line1,
      shipping_address2: address&.line2,
      shipping_city: address&.city,
      shipping_state: address&.state,
      shipping_zip: address&.postal_code,
      shipping_country: address&.country,
      shipping_cents: stripe_session.total_details&.amount_shipping.to_i,
      total_cents: stripe_session.amount_total.to_i
    )

    decrement_stock(order)
    OrderMailer.receipt(order).deliver_later if send_receipt && order.buyer_email.present?
    true
  end

  # Stripe moved Checkout::Session#shipping_details under collected_information in
  # API version 2025-03-31.basil; the field is absent entirely on current versions,
  # so reading it directly silently wrote nil into every shipping column. Prefer the
  # new location and fall back to the legacy one so older or replayed event payloads
  # still populate the address.
  def shipping_details_for(stripe_session)
    stripe_session.try(:collected_information)&.shipping_details ||
      stripe_session.try(:shipping_details)
  end

  # A retrieved session may carry an expanded PaymentIntent object where the
  # webhook payload carries a bare id.
  def payment_intent_id(stripe_session)
    intent = stripe_session.payment_intent
    intent.respond_to?(:id) ? intent.id : intent
  end

  def decrement_stock(order)
    order.order_items.each do |item|
      next unless item.variant
      item.variant.with_lock do
        new_stock = [ item.variant.stock_quantity - item.quantity, 0 ].max
        item.variant.update!(stock_quantity: new_stock)
      end
    end
  end
end
