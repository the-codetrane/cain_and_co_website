require "test_helper"

class Admin::ProductsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(User.take) }

  test "index requires authentication" do
    reset!
    get admin_products_path
    assert_redirected_to new_session_path
  end

  test "index lists all products" do
    get admin_products_path
    assert_response :success
    assert_match products(:published_shirt).name, response.body
    assert_match products(:draft_vinyl).name, response.body
  end

  test "show renders the product and its variants" do
    get admin_product_path(products(:published_shirt))
    assert_response :success
    assert_match variants(:shirt_small).name, response.body
  end

  test "new renders the form" do
    get new_admin_product_path
    assert_response :success
  end

  test "create saves a new product and redirects to show" do
    assert_difference -> { Product.count }, 1 do
      post admin_products_path, params: { product: {
        name: "New Hoodie", description: "Warm.", published: "0", featured: "0"
      } }
    end
    assert_redirected_to admin_product_path(Product.last)
    assert_equal "Product created.", flash[:notice]
  end

  test "create re-renders new on validation failure" do
    post admin_products_path, params: { product: { name: "" } }
    assert_response :unprocessable_entity
  end

  test "update changes attributes and redirects to show" do
    patch admin_product_path(products(:draft_vinyl)), params: { product: { published: "1" } }
    assert_redirected_to admin_product_path(products(:draft_vinyl))
    assert products(:draft_vinyl).reload.published?
  end

  test "destroy removes the product and all its variants" do
    product = products(:draft_vinyl)
    variant_count_before = Variant.count
    assert_difference -> { Product.count }, -1 do
      delete admin_product_path(product)
    end
    assert Variant.count < variant_count_before
    assert_redirected_to admin_products_path
  end
end
