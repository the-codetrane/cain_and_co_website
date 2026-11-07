require "test_helper"

class InvitationTest < ActiveSupport::TestCase
  test "normalizes email" do
    assert_equal "new@example.com", Invitation.new(email: " NEW@Example.com ").email
  end

  test "rejects an address that already has an account" do
    invitation = Invitation.issue(email: users(:member).email_address)
    assert_not invitation.persisted?
    assert_includes invitation.errors[:email], "already has an account"
  end

  test "rejects a malformed address" do
    assert_not Invitation.issue(email: "not-an-email").persisted?
  end

  test "issuing again refreshes the invite and kills the earlier link" do
    invitation = invitations(:pending)
    old_token = invitation.generate_token_for(:acceptance)

    assert_no_difference -> { Invitation.count } do
      Invitation.issue(email: invitation.email, admin: true)
    end

    assert_nil Invitation.find_by_token_for(:acceptance, old_token)
    assert invitation.reload.admin?
    assert_not invitation.expired?
  end

  test "token expires after 7 days" do
    invitation = invitations(:pending)
    token = invitation.generate_token_for(:acceptance)

    assert_equal invitation, Invitation.find_by_token_for(:acceptance, token)
    travel 7.days + 1.minute
    assert_nil Invitation.find_by_token_for(:acceptance, token)
  end

  test "expired? follows sent_at" do
    assert invitations(:expired).expired?
    assert_not invitations(:pending).expired?
  end

  test "accept creates the user and consumes the invitation" do
    invitation = invitations(:pending_admin)
    user = invitation.accept(password: "s3cret-passphrase", password_confirmation: "s3cret-passphrase")

    assert user.persisted?
    assert user.admin?
    assert_equal invitation.email, user.email_address
    assert_not Invitation.exists?(invitation.id)
  end

  test "accept can't override the invited email or admin flag" do
    user = invitations(:pending).accept(password: "s3cret-passphrase", password_confirmation: "s3cret-passphrase",
                                        email_address: "other@example.com", admin: true)
    assert_equal "pending@example.com", user.email_address
    assert_not user.admin?
  end

  test "failed accept keeps the invitation" do
    invitation = invitations(:pending)
    user = invitation.accept(password: "s3cret-passphrase", password_confirmation: "different")

    assert_not user.persisted?
    assert Invitation.exists?(invitation.id)
  end
end
