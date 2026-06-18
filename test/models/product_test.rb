require "test_helper"

class ProductTest < ActiveSupport::TestCase
  test "name is required" do
    product = Product.new(published: false, featured: false)
    assert_not product.valid?
    assert_includes product.errors[:name], "can't be blank"
  end

  test "published scope returns only published products" do
    assert_includes Product.published.to_a, products(:published_shirt)
    assert_not_includes Product.published.to_a, products(:draft_vinyl)
  end

  test "featured scope returns featured products" do
    assert_includes Product.featured.to_a, products(:published_shirt)
  end

  test "lowest_price_cents returns the minimum variant price" do
    assert_equal 2500, products(:published_shirt).lowest_price_cents
  end

  test "lowest_price_cents is nil with no variants" do
    product = Product.create!(name: "Empty", published: false, featured: false)
    assert_nil product.lowest_price_cents
  end

  test "in_stock? is true when any variant has stock" do
    assert products(:published_shirt).in_stock?
  end

  test "in_stock? is false when all variants are out of stock" do
    product = products(:published_shirt)
    product.variants.update_all(stock_quantity: 0)
    assert_not product.in_stock?
  end
end
