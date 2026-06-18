require "test_helper"

class CartItemTest < ActiveSupport::TestCase
  test "quantity must be positive" do
    item = CartItem.new(cart: carts(:with_items), variant: variants(:shirt_small), quantity: 0)
    assert_not item.valid?
    assert_includes item.errors[:quantity], "must be greater than 0"
  end

  test "subtotal_cents multiplies unit price by quantity" do
    item = cart_items(:shirt_in_cart)
    assert_equal item.variant.price_cents * item.quantity, item.subtotal_cents
  end
end
