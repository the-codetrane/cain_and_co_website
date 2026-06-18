require "test_helper"

class CartsControllerTest < ActionDispatch::IntegrationTest
  test "show renders empty cart without login" do
    get cart_path
    assert_response :success
    assert_select "h1", "Your cart"
    assert_match "empty", response.body
  end

  test "show renders cart items when a cart exists in the session" do
    post cart_cart_items_path, params: { variant_id: variants(:shirt_small).id }
    get cart_path
    assert_response :success
    assert_match products(:published_shirt).name, response.body
  end
end
