require "test_helper"

class OrderItemTest < ActiveSupport::TestCase
  test "variant_name and unit_price_cents are required" do
    item = OrderItem.new(order: orders(:one), quantity: 1)
    assert_not item.valid?
    assert_includes item.errors[:variant_name], "can't be blank"
    assert_includes item.errors[:unit_price_cents], "can't be blank"
  end

  test "quantity must be positive" do
    item = OrderItem.new(order: orders(:one), variant_name: "Widget", unit_price_cents: 1000, quantity: 0)
    assert_not item.valid?
    assert_includes item.errors[:quantity], "must be greater than 0"
  end

  test "subtotal_cents multiplies unit price by quantity" do
    item = order_items(:shirt_in_paid_order)
    assert_equal item.unit_price_cents * item.quantity, item.subtotal_cents
  end
end
