# Weight-based domestic shipping rates for a cart.
#
# Stripe's hosted Checkout collects the buyer's address on its own page, *after* the
# session — and therefore its shipping_options — has already been created, so the
# destination is unknown at the only moment we get to price shipping. The cart
# contents are known, though, and for domestic parcel post weight drives far more of
# the cost than distance does: a tee costs about the same to send to Ohio or Oregon,
# while a two-record order costs nowhere near a tee. So rates tier on total packed
# weight, priced a little above USPS Ground Advantage retail so a heavy order does
# not ship at a loss.
class ShippingRate
  # Added to the summed item weight to cover the mailer or box, filler and label.
  PACKAGING_OZ = 3

  # [ inclusive max packed weight in oz, price in cents ], lightest first. Anything
  # heavier than the last tier falls through to the per-pound overage below.
  TIERS = [
    [ 8, 500 ],
    [ 16, 650 ],
    [ 32, 800 ],
    [ 48, 1000 ],
    [ 80, 1300 ]
  ].freeze

  OUNCES_PER_POUND = 16

  # Every pound (or part of one) past the top tier adds this much.
  OVERAGE_CENTS_PER_POUND = 150

  DELIVERY_ESTIMATE = {
    minimum: { unit: "business_day", value: 5 },
    maximum: { unit: "business_day", value: 10 }
  }.freeze

  DISPLAY_NAME = "Standard Shipping"

  def self.for_cart(cart)
    new(cart.shipping_weight_oz)
  end

  attr_reader :item_weight_oz

  def initialize(item_weight_oz)
    @item_weight_oz = item_weight_oz.to_i
  end

  def packed_weight_oz
    item_weight_oz + PACKAGING_OZ
  end

  def cents
    tier = TIERS.find { |max_oz, _| packed_weight_oz <= max_oz }
    return tier.last if tier

    top_oz, top_cents = TIERS.last
    pounds_over = ((packed_weight_oz - top_oz).to_f / OUNCES_PER_POUND).ceil
    top_cents + (pounds_over * OVERAGE_CENTS_PER_POUND)
  end

  # The shipping_options entry Stripe::Checkout::Session.create expects.
  def stripe_shipping_option
    {
      shipping_rate_data: {
        type: "fixed_amount",
        fixed_amount: { amount: cents, currency: "usd" },
        display_name: DISPLAY_NAME,
        delivery_estimate: DELIVERY_ESTIMATE
      }
    }
  end
end
