require "test_helper"

class InvitationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @invitation = invitations(:pending)
    @token = @invitation.generate_token_for(:acceptance)
  end

  test "edit shows the form with the invited email" do
    get edit_invitation_path(@token)
    assert_response :success
    assert_select "input[readonly][value=?]", @invitation.email
  end

  test "viewing the form doesn't consume the invitation" do
    get edit_invitation_path(@token)
    assert Invitation.exists?(@invitation.id)
  end

  test "edit with a bad token redirects to sign in" do
    get edit_invitation_path("bogus")
    assert_redirected_to new_session_path
  end

  test "edit with an expired token redirects to sign in" do
    travel 8.days
    get edit_invitation_path(@token)
    assert_redirected_to new_session_path
  end

  test "update creates the account and signs them in" do
    assert_difference -> { User.count }, 1 do
      patch invitation_path(@token), params: { password: "s3cret-passphrase", password_confirmation: "s3cret-passphrase" }
    end

    assert_redirected_to admin_root_url
    assert cookies[:session_id].present?
    assert User.authenticate_by(email_address: @invitation.email, password: "s3cret-passphrase")
  end

  test "a non-admin invitee lands on the holding page" do
    patch invitation_path(@token), params: { password: "s3cret-passphrase", password_confirmation: "s3cret-passphrase" }
    follow_redirect!
    assert_redirected_to no_access_path
    follow_redirect!
    assert_response :success
    assert_match "have access yet", response.body
  end

  test "an admin invitee lands on the dashboard" do
    token = invitations(:pending_admin).generate_token_for(:acceptance)
    patch invitation_path(token), params: { password: "s3cret-passphrase", password_confirmation: "s3cret-passphrase" }
    follow_redirect!
    assert_response :success
    assert_match "Dashboard", response.body
  end

  test "the link is single-use" do
    patch invitation_path(@token), params: { password: "s3cret-passphrase", password_confirmation: "s3cret-passphrase" }
    reset!

    assert_no_difference -> { User.count } do
      patch invitation_path(@token), params: { password: "other-passphrase", password_confirmation: "other-passphrase" }
    end
    assert_redirected_to new_session_path
  end

  test "mismatched passwords re-render with the invitation intact" do
    assert_no_difference -> { User.count } do
      patch invitation_path(@token), params: { password: "s3cret-passphrase", password_confirmation: "different" }
    end
    assert_response :unprocessable_entity
    assert Invitation.exists?(@invitation.id)
  end

  test "a short password re-renders with the reason and keeps the invitation" do
    assert_no_difference -> { User.count } do
      patch invitation_path(@token), params: { password: "too-short", password_confirmation: "too-short" }
    end
    assert_response :unprocessable_entity
    assert_match "too short", response.body
    assert Invitation.exists?(@invitation.id)
  end

  test "a missing password re-renders instead of erroring" do
    patch invitation_path(@token)
    assert_response :unprocessable_entity
  end

  test "params can't grant admin or change the email" do
    patch invitation_path(@token), params: {
      password: "s3cret-passphrase", password_confirmation: "s3cret-passphrase", admin: true, email_address: "other@example.com"
    }
    user = User.find_by!(email_address: @invitation.email)
    assert_not user.admin?
    assert_not User.exists?(email_address: "other@example.com")
  end
end
