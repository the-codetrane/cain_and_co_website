require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "privacy policy is publicly reachable" do
    get privacy_path
    assert_response :success
    assert_select "h1", "Privacy Policy"
  end

  test "terms of service is publicly reachable" do
    get tos_path
    assert_response :success
    assert_select "h1", "Terms of Service"
  end

  test "legal pages name the operating entity and contact address" do
    [ privacy_path, tos_path ].each do |path|
      get path
      assert_includes response.body, "2100 Enterprises, LLC"
      assert_includes response.body, "info@2100enterprises.com"
    end
  end

  test "footer links to both legal pages" do
    get root_path
    assert_select "footer a[href=?]", privacy_path
    assert_select "footer a[href=?]", tos_path
  end
end
