require "test_helper"

class ShippingRateTest < ActiveSupport::TestCase
  test "adds packaging weight to the summed item weight" do
    assert_equal 6 + ShippingRate::PACKAGING_OZ, ShippingRate.new(6).packed_weight_oz
  end

  test "prices each tier from the packed weight" do
    # Packed weight is item weight + PACKAGING_OZ, so subtract it to land a cart
    # exactly on each tier ceiling.
    ShippingRate::TIERS.each do |max_oz, cents|
      on_ceiling = ShippingRate.new(max_oz - ShippingRate::PACKAGING_OZ)
      assert_equal cents, on_ceiling.cents,
        "a cart packing to exactly #{max_oz} oz should charge #{cents}"
    end
  end

  test "an ounce over a tier ceiling moves up to the next tier" do
    first_max, _first_cents = ShippingRate::TIERS.first
    _second_max, second_cents = ShippingRate::TIERS.second

    over = ShippingRate.new(first_max - ShippingRate::PACKAGING_OZ + 1)
    assert_equal second_cents, over.cents
  end

  test "packaging alone cannot exceed the lightest tier" do
    assert_equal ShippingRate::TIERS.first.last, ShippingRate.new(0).cents
  end

  test "charges a per-pound overage past the heaviest tier" do
    top_oz, top_cents = ShippingRate::TIERS.last

    one_oz_over = ShippingRate.new(top_oz - ShippingRate::PACKAGING_OZ + 1)
    assert_equal top_cents + ShippingRate::OVERAGE_CENTS_PER_POUND, one_oz_over.cents,
      "a part-pound over the top tier still bills a whole pound"

    two_lb_over = ShippingRate.new(top_oz - ShippingRate::PACKAGING_OZ + (2 * ShippingRate::OUNCES_PER_POUND))
    assert_equal top_cents + (2 * ShippingRate::OVERAGE_CENTS_PER_POUND), two_lb_over.cents
  end

  test "rates never go down as weight goes up" do
    rates = (0..200).map { |oz| ShippingRate.new(oz).cents }
    assert_equal rates, rates.sort, "shipping must be monotonic in weight"
  end

  test "builds a fixed_amount shipping option Stripe accepts" do
    option = ShippingRate.new(6).stripe_shipping_option[:shipping_rate_data]

    assert_equal "fixed_amount", option[:type]
    assert_equal ShippingRate.new(6).cents, option[:fixed_amount][:amount]
    assert_equal "usd", option[:fixed_amount][:currency]
    assert_equal ShippingRate::DISPLAY_NAME, option[:display_name]
    assert_equal ShippingRate::DELIVERY_ESTIMATE, option[:delivery_estimate]
  end

  test "for_cart rates the cart's total item weight" do
    cart = Cart.create!
    cart.add_variant(variants(:shirt_small), quantity: 2)

    rate = ShippingRate.for_cart(cart)
    assert_equal 2 * variants(:shirt_small).weight_oz, rate.item_weight_oz
    assert_equal ShippingRate.new(2 * variants(:shirt_small).weight_oz).cents, rate.cents
  end
end
