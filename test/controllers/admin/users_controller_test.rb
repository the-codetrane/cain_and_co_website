require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:one)) }

  test "index requires authentication" do
    sign_out
    get admin_users_path
    assert_redirected_to new_session_path
  end

  test "index lists users and invitation status" do
    get admin_users_path
    assert_response :success
    assert_match users(:member).email_address, response.body
    assert_match invitations(:pending).email, response.body
    assert_match invitations(:expired).email, response.body
    assert_match "will be an admin", response.body
  end

  test "index offers no admin control on your own row" do
    get admin_users_path
    assert_select "##{dom_id(users(:one))} form", count: 0
    assert_select "##{dom_id(users(:two))} form"
  end

  test "grant replaces the row in place" do
    patch admin_user_path(users(:member)), params: { user: { admin: true } }, as: :turbo_stream

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match %(target="#{dom_id(users(:member))}"), response.body
    assert_match "Remove admin", response.body
    assert users(:member).reload.admin?
  end

  test "revoke" do
    patch admin_user_path(users(:two)), params: { user: { admin: false } }
    assert_redirected_to admin_users_path
    assert_not users(:two).reload.admin?
  end

  test "the value is explicit, so repeating a grant doesn't undo it" do
    2.times { patch admin_user_path(users(:member)), params: { user: { admin: true } } }
    assert users(:member).reload.admin?
  end

  test "you can't change your own access" do
    patch admin_user_path(users(:one)), params: { user: { admin: false } }

    assert_redirected_to admin_users_path
    assert_equal "You can't change your own admin access.", flash[:alert]
    assert users(:one).reload.admin?
  end

  test "update can't touch any other attribute" do
    patch admin_user_path(users(:member)), params: { user: { admin: true, email_address: "x@example.com", password: "hijacked1" } }

    user = users(:member).reload
    assert_equal "member@example.com", user.email_address
    assert_not User.authenticate_by(email_address: user.email_address, password: "hijacked1")
  end

  test "revoked access takes effect on a live session" do
    sign_out
    sign_in_as(users(:two))
    get admin_root_path
    assert_response :success

    users(:two).update!(admin: false)
    get admin_root_path
    assert_redirected_to no_access_path
  end

  test "non-admins can't grant themselves access" do
    sign_out
    sign_in_as(users(:member))

    patch admin_user_path(users(:member)), params: { user: { admin: true } }
    assert_redirected_to no_access_path
    assert_not users(:member).reload.admin?
  end

  private

  def dom_id(record) = ActionView::RecordIdentifier.dom_id(record)
end
