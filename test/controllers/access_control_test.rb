require "test_helper"

# Locks in the Phase 1 access model: public-by-default site, single admin chokepoint.
class AccessControlTest < ActionDispatch::IntegrationTest
  test "public pages are reachable without logging in" do
    get root_path
    assert_response :success

    get about_path
    assert_response :success
  end

  test "admin area redirects to login when unauthenticated" do
    get admin_root_path
    assert_redirected_to new_session_path
  end

  test "admin area is reachable after signing in" do
    sign_in_as(users(:one))
    get admin_root_path
    assert_response :success
  end
end
