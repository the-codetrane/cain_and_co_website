class SubscriberMailer < ApplicationMailer
  # Double opt-in confirmation. The token is signed and expires in 2 days
  # (see Subscriber#generates_token_for :confirmation).
  def confirmation
    @subscriber = params[:subscriber]
    @confirm_url = newsletter_confirm_url(token: @subscriber.generate_token_for(:confirmation))
    mail to: @subscriber.email, subject: "Confirm your Cain & Co. newsletter subscription"
  end
end
