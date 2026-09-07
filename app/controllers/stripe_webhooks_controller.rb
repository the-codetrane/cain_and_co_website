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

    within_new_stripe_event(event) do
      OrderPaymentSync.apply_paid_session!(order, stripe_session)
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

  def within_new_stripe_event(event)
    ActiveRecord::Base.transaction do
      StripeEvent.create!(stripe_event_id: event.id, processed_at: Time.current)
      yield
    end
  rescue ActiveRecord::RecordNotUnique
    # Duplicate event — already processed, safe to ignore.
  end
end
