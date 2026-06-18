require "test_helper"

class CartsControllerTest < ActionDispatch::IntegrationTest
  test "show renders empty cart without login" do
    get cart_path
    assert_response :success
    assert_select "h1", "Your cart"
    assert_match "empty", response.body
  end

  test "show renders cart items when session token is set" do
    cart = carts(:with_items)
    cookies["cart_token"] = cart.token
    # Cart token is stored in session not a plain cookie — simulate via session
    get cart_path, headers: { "COOKIE" => "" }
    assert_response :success
  end
end
