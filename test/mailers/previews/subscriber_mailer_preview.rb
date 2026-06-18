# Preview all emails at http://localhost:3000/rails/mailers/subscriber_mailer
class SubscriberMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/subscriber_mailer/confirmation
  def confirmation
    subscriber = Subscriber.unconfirmed.first || Subscriber.first ||
                 Subscriber.new(email: "fan@example.com")
    SubscriberMailer.with(subscriber: subscriber).confirmation
  end
end
