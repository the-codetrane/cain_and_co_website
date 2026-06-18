require "test_helper"

class CartItemsControllerTest < ActionDispatch::IntegrationTest
  test "create adds an item and redirects to cart" do
    assert_difference -> { CartItem.count }, 1 do
      post cart_cart_items_path, params: { variant_id: variants(:shirt_small).id, quantity: 1 }
    end
    assert_redirected_to cart_path
    assert_equal "Added to cart.", flash[:notice]
  end

  test "create creates a cart when none exists" do
    assert_difference -> { Cart.count }, 1 do
      post cart_cart_items_path, params: { variant_id: variants(:shirt_small).id }
    end
  end

  test "create reuses the existing session cart" do
    # First add creates a cart
    post cart_cart_items_path, params: { variant_id: variants(:shirt_small).id }
    assert_difference -> { Cart.count }, 0 do
      post cart_cart_items_path, params: { variant_id: variants(:vinyl_standard).id }
    end
  end

  test "update with quantity 0 removes the item" do
    # First POST establishes the session cart token
    post cart_cart_items_path, params: { variant_id: variants(:shirt_small).id }
    item = CartItem.last
    patch cart_cart_item_path(item), params: { quantity: 0 }
    assert_redirected_to cart_path
    assert_not CartItem.exists?(item.id)
  end

  test "destroy removes the item" do
    post cart_cart_items_path, params: { variant_id: variants(:shirt_small).id }
    item = CartItem.last
    assert_difference -> { CartItem.count }, -1 do
      delete cart_cart_item_path(item)
    end
    assert_redirected_to cart_path
  end
end
