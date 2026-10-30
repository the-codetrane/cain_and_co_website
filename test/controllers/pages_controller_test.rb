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

  test "meta pixel is not inlined; it is gated behind the consent banner" do
    get root_path
    assert_no_match(/fbevents\.js|fbq\(/, response.body)
    assert_select "body[data-controller=consent][data-consent-pixel-id-value]"
    assert_select "[data-consent-target=banner][hidden]"
  end

  test "footer links to both legal pages" do
    get root_path
    assert_select "footer a[href=?]", privacy_path
    assert_select "footer a[href=?]", tos_path
  end
end
