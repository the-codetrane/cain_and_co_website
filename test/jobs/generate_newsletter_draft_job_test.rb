require "test_helper"

class GenerateNewsletterDraftJobTest < ActiveJob::TestCase
  # Stand-in for NewsletterDrafter, injected via the job's `drafter:` arg.
  class FakeDrafter
    def initialize(html: nil, configured: true, error: nil)
      @html = html
      @configured = configured
      @error = error
    end

    def configured? = @configured

    def call(topic: nil)
      raise @error if @error
      @html
    end
  end

  test "fills the draft body with the generated HTML" do
    newsletter = newsletters(:draft_issue)
    drafter = FakeDrafter.new(html: "<p>Fresh AI draft</p>")

    GenerateNewsletterDraftJob.perform_now(newsletter.id, topic: "tour", drafter: drafter)

    newsletter.reload
    assert_match "Fresh AI draft", newsletter.body.to_plain_text
    assert_match "<p>Fresh AI draft</p>", newsletter.body.body.to_html
  end

  test "no-ops for a non-draft newsletter" do
    newsletter = newsletters(:sent_issue)
    before = newsletter.body.to_s

    GenerateNewsletterDraftJob.perform_now(newsletter.id, drafter: FakeDrafter.new(html: "<p>nope</p>"))

    assert_equal before, newsletter.reload.body.to_s
  end

  test "does not raise or change the body when the drafter is not configured" do
    newsletter = newsletters(:draft_issue)
    before = newsletter.body.to_s

    assert_nothing_raised do
      GenerateNewsletterDraftJob.perform_now(newsletter.id, drafter: FakeDrafter.new(configured: false))
    end
    assert_equal before, newsletter.reload.body.to_s
  end

  test "treats an empty result as a soft failure without setting the body" do
    newsletter = newsletters(:draft_issue)
    before = newsletter.body.to_s

    assert_nothing_raised do
      GenerateNewsletterDraftJob.perform_now(newsletter.id, drafter: FakeDrafter.new(html: "  "))
    end
    assert_equal before, newsletter.reload.body.to_s
  end

  test "does not raise when the drafter errors" do
    newsletter = newsletters(:draft_issue)
    drafter = FakeDrafter.new(error: NewsletterDrafter::Error.new("Claude is down"))

    assert_nothing_raised do
      GenerateNewsletterDraftJob.perform_now(newsletter.id, drafter: drafter)
    end
  end

  test "no-ops for a missing newsletter" do
    assert_nothing_raised { GenerateNewsletterDraftJob.perform_now(-1, drafter: FakeDrafter.new(html: "x")) }
  end
end
