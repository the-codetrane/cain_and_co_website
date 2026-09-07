require "test_helper"

class CartTest < ActiveSupport::TestCase
  test "generates a unique token on create" do
    cart = Cart.create!
    assert cart.token.present?
    assert_not_equal cart.token, Cart.create!.token
  end

  test "total_cents sums price * quantity for all items" do
    cart = carts(:with_items)
    assert_equal 5000, cart.total_cents   # shirt_small 2500 * qty 2
  end

  test "item_count sums quantities" do
    assert_equal 2, carts(:with_items).item_count
  end

  test "empty? is true for a cart with no items" do
    assert carts(:empty_cart).empty?
  end

  test "empty? is false for a cart with items" do
    assert_not carts(:with_items).empty?
  end

  test "add_variant creates a new CartItem" do
    cart = carts(:empty_cart)
    assert_difference -> { cart.cart_items.count }, 1 do
      cart.add_variant(variants(:shirt_small), quantity: 1)
    end
  end

  test "add_variant increments quantity on re-add" do
    cart = carts(:with_items)
    item = cart.cart_items.find_by(variant: variants(:shirt_small))
    cart.add_variant(variants(:shirt_small), quantity: 3)
    assert_equal 5, item.reload.quantity
  end

  test "shipping_weight_oz sums item weight times quantity" do
    cart = carts(:empty_cart)
    cart.add_variant(variants(:shirt_small), quantity: 3)

    assert_equal 3 * variants(:shirt_small).weight_oz, cart.reload.shipping_weight_oz
  end

  test "shipping_weight_oz counts an unweighed variant at the default weight" do
    variants(:shirt_small).update!(weight_oz: 0)
    cart = carts(:empty_cart)
    cart.add_variant(variants(:shirt_small), quantity: 2)

    assert_equal 2 * Variant::DEFAULT_WEIGHT_OZ, cart.reload.shipping_weight_oz
  end

  test "an empty cart weighs nothing" do
    assert_equal 0, carts(:empty_cart).shipping_weight_oz
  end
end
