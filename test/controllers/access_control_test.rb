require "test_helper"

# Locks in the access model: public-by-default site, single admin chokepoint.
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

  test "non-admins get the holding page across the admin area" do
    sign_in_as(users(:member))

    [ admin_root_path, admin_users_path, admin_orders_path, admin_subscribers_path,
      admin_newsletters_path, admin_shows_path, admin_products_path, admin_photos_path,
      admin_videos_path, new_admin_push_notification_path ].each do |path|
      get path
      assert_redirected_to no_access_path, path
    end

    follow_redirect!
    assert_response :success
    assert_match "have access yet", response.body
  end

  test "the holding page requires signing in" do
    get no_access_path
    assert_redirected_to new_session_path
  end

  test "admins are sent from the holding page to the dashboard" do
    sign_in_as(users(:one))
    get no_access_path
    assert_redirected_to admin_root_path
  end

  test "non-admins can't write through the admin area" do
    sign_in_as(users(:member))

    assert_no_difference -> { Subscriber.count } do
      post admin_subscribers_path, params: { subscriber: { email: "x@example.com" } }
    end
    assert_redirected_to no_access_path
  end

  test "non-admins can still sign out from the holding page" do
    sign_in_as(users(:member))

    get no_access_path
    assert_select "form[action=?]", session_path

    delete session_path
    assert_redirected_to new_session_path
  end
end
