require "test_helper"

class VariantTest < ActiveSupport::TestCase
  test "name is required" do
    v = Variant.new(product: products(:published_shirt), price_cents: 1000, stock_quantity: 1)
    assert_not v.valid?
    assert_includes v.errors[:name], "can't be blank"
  end

  test "price_cents must be non-negative" do
    v = Variant.new(product: products(:published_shirt), name: "S", price_cents: -1, stock_quantity: 1)
    assert_not v.valid?
  end

  test "stock_quantity must be non-negative" do
    v = Variant.new(product: products(:published_shirt), name: "S", price_cents: 1000, stock_quantity: -1)
    assert_not v.valid?
  end

  test "sku must be unique when present" do
    v = Variant.new(product: products(:published_shirt), name: "XL", price_cents: 2500,
                    stock_quantity: 3, sku: "SHIRT-S")
    assert_not v.valid?
    assert_includes v.errors[:sku], "has already been taken"
  end

  test "sku can be blank on multiple variants" do
    v2 = Variant.new(product: products(:published_shirt), name: "XXL", price_cents: 2000, stock_quantity: 5, sku: nil)
    assert v2.valid?
  end

  test "price_dollars converts cents" do
    assert_in_delta 25.0, variants(:shirt_small).price_dollars, 0.001
  end

  test "in_stock? is true when stock_quantity > 0" do
    assert variants(:shirt_small).in_stock?
  end

  test "in_stock? is false when stock_quantity is 0" do
    assert_not variants(:shirt_large).in_stock?
  end

  test "display_name combines product and variant name" do
    assert_equal "Band Shirt — Small", variants(:shirt_small).display_name
  end
end
