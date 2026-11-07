# Preview all emails at http://localhost:3000/rails/mailers/invitation_mailer
class InvitationMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/invitation_mailer/invite
  def invite
    invitation = Invitation.first || Invitation.new(email: "new.person@example.com", sent_at: Time.current)
    InvitationMailer.with(invitation: invitation).invite
  end
end
