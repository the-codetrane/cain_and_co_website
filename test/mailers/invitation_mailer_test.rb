require "test_helper"

class InvitationMailerTest < ActionMailer::TestCase
  test "invite" do
    invitation = invitations(:pending)
    mail = InvitationMailer.with(invitation: invitation).invite

    assert_equal "You're invited to the Cain & Co. site", mail.subject
    assert_equal [ invitation.email ], mail.to
    assert_match "/invitations/", mail.body.encoded
    assert_match "7 days", mail.body.encoded
  end
end
