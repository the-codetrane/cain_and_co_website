require "test_helper"

class VariantTest < ActiveSupport::TestCase
  test "name is required" do
    v = Variant.new(product: products(:published_shirt), price_cents: 1000, stock_quantity: 1)
    assert_not v.valid?
    assert_includes v.errors[:name], "can't be blank"
  end

  test "price_cents must be non-negative" do
    v = Variant.new(product: products(:published_shirt), name: "M", price_cents: -1, stock_quantity: 1)
    assert_not v.valid?
  end

  test "stock_quantity must be non-negative" do
    v = Variant.new(product: products(:published_shirt), name: "M", price_cents: 1000, stock_quantity: -1)
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
    assert_equal "Band Shirt — S", variants(:shirt_small).display_name
  end

  test "name must be unique per product" do
    v = Variant.new(product: products(:published_shirt), name: "s", price_cents: 2500, stock_quantity: 1)
    assert_not v.valid?
    assert_includes v.errors[:name], "is already an option on this product"
  end

  test "the same name may be reused on a different product" do
    v = Variant.new(product: products(:draft_vinyl), name: "S", price_cents: 2500, stock_quantity: 1)
    assert v.valid?
  end

  test "sizes are positioned by the canonical size order, not creation order" do
    product = Product.create!(name: "Hoodie")
    %w[XL S 2XL M L].each do |size|
      product.variants.create!(name: size, price_cents: 5000, stock_quantity: 1)
    end
    assert_equal %w[S M L XL 2XL], product.variants.reload.map(&:name)
  end

  test "aliases of a size sort into that size's slot" do
    product = Product.create!(name: "Cap")
    large  = product.variants.create!(name: "Large", price_cents: 2000, stock_quantity: 1)
    medium = product.variants.create!(name: "Medium", price_cents: 2000, stock_quantity: 1)
    assert_equal [ medium, large ], product.variants.reload.to_a
  end

  test "non-size variants sort after every size" do
    product = Product.create!(name: "Poster")
    product.variants.create!(name: "Signed", price_cents: 3000, stock_quantity: 1)
    small = product.variants.create!(name: "S", price_cents: 2000, stock_quantity: 1)
    assert_equal small, product.variants.reload.first
    assert_equal "Signed", product.variants.last.name
  end

  test "an explicit position overrides the automatic one" do
    product = Product.create!(name: "Tote")
    last  = product.variants.create!(name: "S", price_cents: 1000, stock_quantity: 1, position: 500)
    first = product.variants.create!(name: "3XL", price_cents: 1000, stock_quantity: 1)
    assert_equal [ first, last ], product.variants.reload.to_a
  end

  test "size? recognises canonical sizes and aliases but not other options" do
    assert Variant.new(name: "2XL").size?
    assert Variant.new(name: "medium").size?
    assert_not Variant.new(name: "Signed").size?
  end

  test "canonical_size maps aliases and is nil for non-sizes" do
    assert_equal "M", Variant.canonical_size("Medium")
    assert_equal "2XL", Variant.canonical_size("xxl")
    assert_equal "One Size", Variant.canonical_size("one size")
    assert_nil Variant.canonical_size("Black")
    assert_nil Variant.canonical_size("")
  end

  test "in_stock scope excludes sold-out variants" do
    assert_includes Variant.in_stock, variants(:shirt_small)
    assert_not_includes Variant.in_stock, variants(:shirt_large)
  end
end
