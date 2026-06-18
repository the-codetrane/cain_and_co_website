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
    rescue JSON::ParserError
      head :bad_request and return
    rescue Stripe::SignatureVerificationError
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

    ActiveRecord::Base.transaction do
      StripeEvent.create!(stripe_event_id: event.id, processed_at: Time.current)

      order.update!(
        status: "paid",
        stripe_payment_intent_id: stripe_session.payment_intent,
        buyer_email: stripe_session.customer_details&.email,
        buyer_name: stripe_session.customer_details&.name,
        shipping_name: stripe_session.shipping_details&.name,
        shipping_address1: stripe_session.shipping_details&.address&.line1,
        shipping_address2: stripe_session.shipping_details&.address&.line2,
        shipping_city: stripe_session.shipping_details&.address&.city,
        shipping_state: stripe_session.shipping_details&.address&.state,
        shipping_zip: stripe_session.shipping_details&.address&.postal_code,
        shipping_country: stripe_session.shipping_details&.address&.country,
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
    end

    OrderMailer.receipt(order).deliver_later
  rescue ActiveRecord::RecordNotUnique
    # Duplicate event — already processed, safe to ignore.
  end

  def handle_checkout_canceled(event)
    stripe_session = event.data.object
    order = Order.find_by(stripe_checkout_session_id: stripe_session.id)
    return unless order&.pending?
    ActiveRecord::Base.transaction do
      StripeEvent.create!(stripe_event_id: event.id, processed_at: Time.current)
      order.update!(status: "canceled")
    end
  rescue ActiveRecord::RecordNotUnique
    # Duplicate event.
  end
end
