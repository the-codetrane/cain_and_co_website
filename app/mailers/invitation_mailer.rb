class InvitationMailer < ApplicationMailer
  # The link is signed and expires (see Invitation#generates_token_for :acceptance).
  def invite
    @invitation = params[:invitation]
    @accept_url = edit_invitation_url(@invitation.generate_token_for(:acceptance))
    mail to: @invitation.email, subject: "You're invited to the Cain & Co. site"
  end
end
