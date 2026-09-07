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

  test "add_sizes creates one variant per selected size" do
    product = Product.create!(name: "Hoodie")
    assert_difference -> { Variant.count }, 3 do
      post add_sizes_admin_product_variants_path(product),
           params: { sizes: %w[M S L], price_cents: 4500, stock_quantity: 7 }
    end
    assert_redirected_to admin_product_path(product)
    assert_equal %w[S M L], product.variants.reload.map(&:name)
    assert product.variants.all? { |v| v.price_cents == 4500 && v.stock_quantity == 7 }
  end

  test "add_sizes skips sizes the product already has" do
    product = products(:published_shirt) # already has S and L
    assert_difference -> { Variant.count }, 1 do
      post add_sizes_admin_product_variants_path(product),
           params: { sizes: %w[S M L], price_cents: 2500, stock_quantity: 3 }
    end
    assert_match "2 already existed", flash[:notice]
  end

  test "add_sizes ignores names outside the size palette" do
    product = Product.create!(name: "Poster")
    assert_difference -> { Variant.count }, 1 do
      post add_sizes_admin_product_variants_path(product),
           params: { sizes: [ "M", "Bogus", "'; DROP TABLE variants; --" ],
                     price_cents: 1000, stock_quantity: 1 }
    end
    assert_equal %w[M], product.variants.reload.map(&:name)
  end

  test "add_sizes with no sizes selected redirects with an alert" do
    product = Product.create!(name: "Tote")
    assert_no_difference -> { Variant.count } do
      post add_sizes_admin_product_variants_path(product), params: { price_cents: 1000, stock_quantity: 1 }
    end
    assert_equal "Pick at least one size.", flash[:alert]
  end

  test "add_sizes requires login" do
    delete session_path
    post add_sizes_admin_product_variants_path(products(:published_shirt)), params: { sizes: %w[M] }
    assert_redirected_to new_session_path
  end

  test "create rejects a duplicate name on the same product" do
    post admin_product_variants_path(products(:published_shirt)), params: { variant: {
      name: "S", price_cents: 2500, stock_quantity: 5
    } }
    assert_response :unprocessable_entity
  end
end
