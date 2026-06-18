require "test_helper"

class ProductsControllerTest < ActionDispatch::IntegrationTest
  test "index renders without login" do
    get products_path
    assert_response :success
    assert_select "h1", "Merch"
  end

  test "index shows published products only" do
    get products_path
    assert_match products(:published_shirt).name, response.body
    assert_no_match products(:draft_vinyl).name, response.body
  end

  test "show renders a published product" do
    get product_path(products(:published_shirt))
    assert_response :success
    assert_match products(:published_shirt).name, response.body
  end

  test "show returns 404 for unpublished product" do
    get product_path(products(:draft_vinyl))
    assert_response :not_found
  end
end
