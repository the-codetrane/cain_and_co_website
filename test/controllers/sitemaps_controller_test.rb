require "test_helper"

class SitemapsControllerTest < ActionDispatch::IntegrationTest
  test "returns valid XML" do
    get sitemap_path
    assert_response :success
    assert_equal "application/xml", response.media_type
  end

  test "includes all static public routes" do
    get sitemap_path
    body = response.body
    assert_includes body, root_url
    assert_includes body, shows_url
    assert_includes body, past_shows_url
    assert_includes body, about_url
    assert_includes body, products_url
  end

  test "includes published product URLs" do
    product = products(:published_shirt)
    get sitemap_path
    assert_includes response.body, product_url(product)
  end

  test "does not include unpublished products" do
    unpublished = Product.where(published: false).first
    skip "no unpublished products in fixtures" unless unpublished
    get sitemap_path
    assert_not_includes response.body, product_url(unpublished)
  end
end
