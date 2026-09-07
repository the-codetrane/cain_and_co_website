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

  test "show renders a size button per variant in size order" do
    get product_path(products(:published_shirt))
    assert_response :success
    assert_select "legend", "Select size"
    assert_select "input[type=radio][name=variant_id]", 1 # only the in-stock size is selectable
    assert_select "input[type=radio][value=?]", variants(:shirt_small).id.to_s
  end

  test "show marks a sold-out size as unselectable rather than hiding it" do
    get product_path(products(:published_shirt))
    assert_select "input[type=radio][value=?]", variants(:shirt_large).id.to_s, count: 0
    assert_select "span.line-through", text: variants(:shirt_large).name
  end

  test "show orders the size buttons S then L regardless of fixture order" do
    product = products(:published_shirt)
    product.variants.update_all(stock_quantity: 5)
    get product_path(product)
    small = response.body.index(%(value="#{variants(:shirt_small).id}"))
    large = response.body.index(%(value="#{variants(:shirt_large).id}"))
    assert small && large, "both size buttons should render"
    assert_operator small, :<, large
  end

  test "show falls back to a hidden field for a single-variant product" do
    product = Product.create!(name: "Tote", published: true)
    product.variants.create!(name: "One Size", price_cents: 1500, stock_quantity: 4)
    get product_path(product)
    assert_select "input[type=hidden][name=variant_id]", 1
    assert_select "input[type=radio][name=variant_id]", 0
  end
end
