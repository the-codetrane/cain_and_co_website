# Preview all emails at http://localhost:3000/rails/mailers/newsletter_mailer
class NewsletterMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/newsletter_mailer/issue
  def issue
    newsletter = Newsletter.last || Newsletter.new(subject: "This month at Cain & Co.").tap do |n|
      n.body = "<h1>New shows announced</h1><p>We're hitting the road this summer.</p>"
    end
    subscriber = Subscriber.active.first || Subscriber.new(email: "fan@example.com")
    NewsletterMailer.with(newsletter: newsletter, subscriber: subscriber).issue
  end
end
