require "test_helper"

class NewsletterMailerTest < ActionMailer::TestCase
  setup do
    @newsletter = newsletters(:draft_issue)
    @subscriber = subscribers(:confirmed_fan)
    @mail = NewsletterMailer.with(newsletter: @newsletter, subscriber: @subscriber).issue
  end

  test "addresses the subscriber with the newsletter subject" do
    assert_equal [ @subscriber.email ], @mail.to
    assert_equal @newsletter.subject, @mail.subject
  end

  test "is multipart with html and text" do
    assert @mail.multipart?
    types = @mail.parts.map(&:content_type)
    assert types.any? { |t| t.start_with?("text/plain") }
    assert types.any? { |t| t.start_with?("text/html") }
  end

  test "carries RFC 8058 one-click unsubscribe headers" do
    assert_match %r{/newsletter/unsubscribe/}, @mail.header["List-Unsubscribe"].to_s
    assert_equal "List-Unsubscribe=One-Click", @mail.header["List-Unsubscribe-Post"].to_s
  end

  test "includes the unsubscribe link and rich-text body in the html part" do
    html = @mail.html_part.body.to_s
    assert_match "Unsubscribe", html
    assert_match "Hello from the band", html
  end

  test "renders a plain-text alternative of the body" do
    text = @mail.text_part.body.to_s
    assert_match "Hello from the band", text
    assert_match "Unsubscribe:", text
  end
end
