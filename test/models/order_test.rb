require "test_helper"

class OrderTest < ActiveSupport::TestCase
  test "status must be a valid value" do
    order = Order.new(status: "bogus")
    assert_not order.valid?
  end

  test "paid? returns true for paid orders" do
    assert orders(:one).paid?
    assert_not orders(:two).paid?
  end

  test "fulfilled? returns true for fulfilled orders" do
    assert orders(:two).fulfilled?
    assert_not orders(:one).fulfilled?
  end

  test "total_dollars converts cents" do
    assert_in_delta 30.0, orders(:one).total_dollars, 0.001
  end

  test "shipping_address joins non-blank fields" do
    order = orders(:one)
    addr = order.shipping_address
    assert_includes addr, order.shipping_name
    assert_includes addr, order.shipping_city
  end
end
