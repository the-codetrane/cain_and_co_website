require "test_helper"

class Admin::VariantsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(User.take) }

  test "new renders the form" do
    get new_admin_product_variant_path(products(:published_shirt))
    assert_response :success
  end

  test "create adds a variant and redirects to product show" do
    assert_difference -> { Variant.count }, 1 do
      post admin_product_variants_path(products(:published_shirt)), params: { variant: {
        name: "Medium", price_cents: 2500, stock_quantity: 5, sku: ""
      } }
    end
    assert_redirected_to admin_product_path(products(:published_shirt))
    assert_equal "Variant added.", flash[:notice]
  end

  test "create re-renders new on validation failure" do
    post admin_product_variants_path(products(:published_shirt)), params: { variant: {
      name: "", price_cents: 0, stock_quantity: 0
    } }
    assert_response :unprocessable_entity
  end

  test "update changes the variant" do
    patch admin_product_variant_path(products(:published_shirt), variants(:shirt_small)),
          params: { variant: { stock_quantity: 99 } }
    assert_redirected_to admin_product_path(products(:published_shirt))
    assert_equal 99, variants(:shirt_small).reload.stock_quantity
  end

  test "destroy removes the variant" do
    assert_difference -> { Variant.count }, -1 do
      delete admin_product_variant_path(products(:published_shirt), variants(:shirt_small))
    end
    assert_redirected_to admin_product_path(products(:published_shirt))
  end
end
