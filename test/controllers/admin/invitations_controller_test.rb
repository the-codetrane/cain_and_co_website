require "test_helper"

class Admin::InvitationsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:one)) }

  test "new renders the form" do
    get new_admin_invitation_path
    assert_response :success
  end

  test "create stores the invitation and emails it" do
    assert_difference -> { Invitation.count }, 1 do
      assert_enqueued_emails 1 do
        post admin_invitations_path, params: { invitation: { email: "New@Example.com", admin: "0" } }
      end
    end

    assert_redirected_to admin_users_path
    assert_not Invitation.find_by!(email: "new@example.com").admin?
  end

  test "create can grant admin at invite time" do
    post admin_invitations_path, params: { invitation: { email: "new@example.com", admin: "1" } }
    assert Invitation.find_by!(email: "new@example.com").admin?
  end

  test "create without the admin param defaults to non-admin" do
    post admin_invitations_path, params: { invitation: { email: "new@example.com" } }
    assert_not Invitation.find_by!(email: "new@example.com").admin?
  end

  test "re-inviting an expired address sends a fresh invite" do
    assert_no_difference -> { Invitation.count } do
      assert_enqueued_emails 1 do
        post admin_invitations_path, params: { invitation: { email: invitations(:expired).email, admin: "0" } }
      end
    end
    assert_not invitations(:expired).reload.expired?
  end

  test "create rejects an address with an account and sends nothing" do
    assert_no_difference -> { Invitation.count } do
      assert_enqueued_emails 0 do
        post admin_invitations_path, params: { invitation: { email: users(:member).email_address, admin: "0" } }
      end
    end
    assert_response :unprocessable_entity
    assert_match "already has an account", response.body
  end

  test "a failed re-invite re-renders a form that posts to create" do
    invitation = invitations(:pending)
    User.create!(email_address: invitation.email, password: "s3cret-passphrase")

    assert_enqueued_emails 0 do
      post admin_invitations_path, params: { invitation: { email: invitation.email, admin: "0" } }
    end
    assert_response :unprocessable_entity
    assert_select "form[action=?][method=post]", admin_invitations_path
    assert_select "form[action=?] input[name=_method]", admin_invitations_path, count: 0
  end

  test "cancelling deletes the invitation and kills its link" do
    invitation = invitations(:pending_admin)
    token = invitation.generate_token_for(:acceptance)

    assert_difference -> { Invitation.count }, -1 do
      delete admin_invitation_path(invitation)
    end
    assert_redirected_to admin_users_path

    sign_out
    get edit_invitation_path(token)
    assert_redirected_to new_session_path
  end

  test "non-admins can't cancel" do
    sign_out
    sign_in_as(users(:member))

    assert_no_difference -> { Invitation.count } do
      delete admin_invitation_path(invitations(:pending))
    end
    assert_redirected_to no_access_path
  end

  test "non-admins can't invite" do
    sign_out
    sign_in_as(users(:member))

    assert_no_difference -> { Invitation.count } do
      post admin_invitations_path, params: { invitation: { email: "new@example.com", admin: "1" } }
    end
    assert_redirected_to no_access_path
  end
end
