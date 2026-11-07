require "test_helper"

class Admin::ProductsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:one)) }

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

  test "create stores uploaded images under the Product Images folder" do
    post admin_products_path, params: { product: { name: "Poster", images: [ "", image_upload ] } }

    blob = Product.find_by!(name: "Poster").images.sole.blob
    assert_match %r{\AProduct Images/[a-z0-9]{28}\z}, blob.key
    assert_equal "test_photo.gif", blob.filename.to_s
    assert blob.service.exist?(blob.key)
  end

  test "update with new images stores them under the Product Images folder" do
    product = products(:published_shirt)

    patch admin_product_path(product), params: { product: { images: [ "", image_upload ] } }

    assert_match %r{\AProduct Images/}, product.reload.images.sole.blob.key
  end

  test "update without choosing a file keeps the existing images" do
    product = products(:published_shirt)
    product.images.attach(io: file_fixture("test_photo.gif").open, filename: "test_photo.gif")

    patch admin_product_path(product), params: { product: { name: "Renamed", images: [ "" ] } }

    assert_equal "Renamed", product.reload.name
    assert_equal 1, product.images.count
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

  private

  def image_upload
    fixture_file_upload("test_photo.gif", "image/gif")
  end
end
