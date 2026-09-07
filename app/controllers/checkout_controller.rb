class CheckoutController < ApplicationController
  def create
    cart = find_cart
    redirect_to cart_path, alert: "Your cart is empty." and return if cart.nil? || cart.empty?

    rate = ShippingRate.for_cart(cart)
    order = build_order_from_cart(cart, rate)
    stripe_session = Stripe::Checkout::Session.create(stripe_params(order, rate))
    order.update_column(:stripe_checkout_session_id, stripe_session.id)

    redirect_to stripe_session.url, allow_other_host: true
  rescue Stripe::StripeError
    order&.destroy
    redirect_to cart_path, alert: "Something went wrong. Please try again."
  end

  private

  def find_cart
    Cart.includes(cart_items: { variant: :product })
        .find_by(token: session[:cart_token])
  end

  # The shipping figures recorded here are the estimate we quote Stripe. The webhook
  # overwrites both from the completed session, which stays authoritative — this just
  # keeps a pending order internally consistent instead of showing $0 shipping.
  def build_order_from_cart(cart, rate)
    ActiveRecord::Base.transaction do
      order = Order.create!(
        status: "pending",
        subtotal_cents: cart.total_cents,
        shipping_cents: rate.cents,
        total_cents: cart.total_cents + rate.cents
      )
      cart.cart_items.each do |item|
        order.order_items.create!(
          variant: item.variant,
          variant_name: item.variant.display_name,
          unit_price_cents: item.variant.price_cents,
          quantity: item.quantity
        )
      end
      order
    end
  end

  def stripe_params(order, rate)
    {
      mode: "payment",
      client_reference_id: order.id.to_s,
      line_items: order.order_items.map { |item|
        {
          price_data: {
            currency: "usd",
            unit_amount: item.unit_price_cents,
            product_data: { name: item.variant_name }
          },
          quantity: item.quantity
        }
      },
      shipping_address_collection: { allowed_countries: [ "US" ] },
      shipping_options: [ rate.stripe_shipping_option ],
      # Stripe substitutes the literal "{CHECKOUT_SESSION_ID}" template string into
      # these URLs. Passing it through a route helper as a query param percent-encodes
      # the braces to %7B...%7D, which Stripe does not recognize, so the placeholder
      # would reach OrdersController#success verbatim and fail its session_id check.
      # Append it as a raw string to keep the braces intact.
      success_url: "#{order_success_url(order)}?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: "#{order_cancel_url(order)}?session_id={CHECKOUT_SESSION_ID}"
    }
  end
end
