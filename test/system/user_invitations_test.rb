require "application_system_test_case"

class UserInvitationsTest < ApplicationSystemTestCase
  test "an admin invites someone, who accepts and is then granted admin in place" do
    sign_in users(:one)

    visit admin_users_path
    click_on "Invite user"
    fill_in "Email", with: "new.person@example.com"
    click_on "Send invitation"

    assert_text "Invitation sent to new.person@example.com"
    assert_text "pending"

    token = Invitation.find_by!(email: "new.person@example.com").generate_token_for(:acceptance)
    click_on "Sign out"
    assert_text "Admin sign in"

    visit edit_invitation_path(token)
    fill_in "Password (at least 12 characters)", with: "s3cret-passphrase"
    fill_in "Confirm password", with: "s3cret-passphrase"
    click_on "Create account"

    assert_text "You don't have access yet"
    assert_current_path no_access_path

    # Must not sit on the used invitation link, or refreshing reports it as invalid.
    page.refresh
    assert_text "You don't have access yet"
    click_on "Sign out"
    assert_text "Admin sign in"

    sign_in users(:one)
    visit admin_users_path
    invitee = User.find_by!(email_address: "new.person@example.com")
    assert_not Invitation.exists?(email: "new.person@example.com")

    # A marker on the window survives a Turbo Stream but not a page load.
    page.execute_script("window.stillSamePage = true")
    within("#user_#{invitee.id}") do
      assert_text "no access"
      accept_confirm { click_on "Make admin" }
      assert_button "Remove admin"
      assert_text "admin"
    end
    assert page.evaluate_script("window.stillSamePage")
    assert invitee.reload.admin?

    within("#user_#{invitee.id}") do
      accept_confirm { click_on "Remove admin" }
      assert_button "Make admin"
    end
    assert_not invitee.reload.admin?

    within("#invitation_#{invitations(:pending).id}") do
      accept_confirm { click_on "Cancel invite" }
    end
    assert_text "Invitation to pending@example.com cancelled."
    assert_not Invitation.exists?(invitations(:pending).id)
  end

  private

  def sign_in(user)
    visit new_session_path
    fill_in "Email", with: user.email_address
    fill_in "Password", with: "password"
    click_on "Sign in"
    assert_text "Dashboard"
  end
end
