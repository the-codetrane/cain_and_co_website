class NewsletterMailer < ApplicationMailer
  # One issue of the newsletter to one subscriber. Delivered per-recipient by
  # DeliverNewsletterJob so each message carries that subscriber's own
  # one-click unsubscribe link (RFC 8058 — required by Gmail/Yahoo for bulk mail).
  def issue
    @newsletter = params[:newsletter]
    @subscriber = params[:subscriber]
    @unsubscribe_url = newsletter_unsubscribe_url(token: @subscriber.generate_token_for(:unsubscribe))

    # List-level one-click unsubscribe. The POST variant lets mailbox providers
    # unsubscribe the user without rendering our page; the route is CSRF-exempt.
    headers["List-Unsubscribe"] = "<#{@unsubscribe_url}>"
    headers["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"

    mail to: @subscriber.email, subject: @newsletter.subject
  end
end
