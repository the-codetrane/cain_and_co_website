class CheckoutController < ApplicationController
  def create
    cart = find_cart
    redirect_to cart_path, alert: "Your cart is empty." and return if cart.nil? || cart.empty?

    order = build_order_from_cart(cart)
    stripe_session = Stripe::Checkout::Session.create(stripe_params(order))
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

  def build_order_from_cart(cart)
    ActiveRecord::Base.transaction do
      order = Order.create!(
        status: "pending",
        subtotal_cents: cart.total_cents,
        shipping_cents: 0,
        total_cents: cart.total_cents
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

  def stripe_params(order)
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
      shipping_options: [
        {
          shipping_rate_data: {
            type: "fixed_amount",
            fixed_amount: { amount: 800, currency: "usd" },
            display_name: "Standard Shipping",
            delivery_estimate: {
              minimum: { unit: "business_day", value: 5 },
              maximum: { unit: "business_day", value: 10 }
            }
          }
        }
      ],
      success_url: order_success_url(order, session_id: "{CHECKOUT_SESSION_ID}"),
      cancel_url: order_cancel_url(order, session_id: "{CHECKOUT_SESSION_ID}")
    }
  end
end
