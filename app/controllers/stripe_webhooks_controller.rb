# Inherits from ActionController::Base directly — skips ApplicationController's
# allow_browser and Authentication concerns, which are irrelevant for server-to-server POSTs.
class StripeWebhooksController < ActionController::Base
  skip_forgery_protection

  def create
    payload    = request.body.read
    sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
    webhook_secret = Rails.application.credentials.dig(:stripe, :webhook_secret)

    begin
      event = Stripe::Webhook.construct_event(payload, sig_header, webhook_secret)
    rescue JSON::ParserError, Stripe::SignatureVerificationError
      head :bad_request and return
    end

    case event.type
    when "checkout.session.completed", "checkout.session.async_payment_succeeded"
      handle_checkout_completed(event)
    when "checkout.session.expired", "checkout.session.async_payment_failed"
      handle_checkout_canceled(event)
    end

    head :ok
  end

  private

  def handle_checkout_completed(event)
    stripe_session = event.data.object
    return unless stripe_session.payment_status == "paid"

    order = Order.find_by(stripe_checkout_session_id: stripe_session.id)
    return unless order
    return if order.paid? || order.fulfilled?

    shipping = shipping_details_for(stripe_session)
    address  = shipping&.address

    within_new_stripe_event(event) do
      order.update!(
        status: "paid",
        stripe_payment_intent_id: stripe_session.payment_intent,
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

      order.order_items.each do |item|
        next unless item.variant
        item.variant.with_lock do
          new_stock = [ item.variant.stock_quantity - item.quantity, 0 ].max
          item.variant.update!(stock_quantity: new_stock)
        end
      end

      OrderMailer.receipt(order).deliver_later
    end
  end

  def handle_checkout_canceled(event)
    stripe_session = event.data.object
    order = Order.find_by(stripe_checkout_session_id: stripe_session.id)
    return unless order&.pending?

    within_new_stripe_event(event) do
      order.update!(status: "canceled")
    end
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

  def within_new_stripe_event(event)
    ActiveRecord::Base.transaction do
      StripeEvent.create!(stripe_event_id: event.id, processed_at: Time.current)
      yield
    end
  rescue ActiveRecord::RecordNotUnique
    # Duplicate event — already processed, safe to ignore.
  end
end
