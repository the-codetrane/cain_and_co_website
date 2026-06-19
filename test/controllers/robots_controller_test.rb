require "test_helper"

class RobotsControllerTest < ActionDispatch::IntegrationTest
  test "returns text/plain" do
    get robots_path
    assert_response :success
    assert_equal "text/plain", response.media_type
  end

  test "disallows admin paths" do
    get robots_path
    assert_includes response.body, "Disallow: /admin"
  end

  test "sitemap URL uses request host" do
    get robots_path
    assert_includes response.body, "Sitemap: http://www.example.com/sitemap.xml"
  end
end
