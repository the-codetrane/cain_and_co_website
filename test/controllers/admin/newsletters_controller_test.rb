require "test_helper"

class Admin::NewslettersControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(User.take) }

  test "index requires authentication" do
    reset!
    get admin_newsletters_path
    assert_redirected_to new_session_path
  end

  test "index lists newsletters" do
    get admin_newsletters_path
    assert_response :success
    assert_match newsletters(:draft_issue).subject, response.body
  end

  test "show renders status and body" do
    get admin_newsletter_path(newsletters(:draft_issue))
    assert_response :success
    assert_match "Hello from the band", response.body
  end

  test "new renders the trix editor" do
    get new_admin_newsletter_path
    assert_response :success
    assert_match "trix-editor", response.body
  end

  test "create saves a draft" do
    assert_difference -> { Newsletter.count }, 1 do
      post admin_newsletters_path, params: { newsletter: { subject: "Hello", body: "<div>Hi fans</div>" } }
    end
    assert_redirected_to admin_newsletter_path(Newsletter.last)
    assert Newsletter.last.draft?
  end

  test "create rejects a blank newsletter" do
    assert_no_difference -> { Newsletter.count } do
      post admin_newsletters_path, params: { newsletter: { subject: "", body: "" } }
    end
    assert_response :unprocessable_entity
  end

  test "update edits a draft" do
    patch admin_newsletter_path(newsletters(:draft_issue)), params: { newsletter: { subject: "Updated" } }
    assert_redirected_to admin_newsletter_path(newsletters(:draft_issue))
    assert_equal "Updated", newsletters(:draft_issue).reload.subject
  end

  test "update refuses to edit a sent newsletter" do
    patch admin_newsletter_path(newsletters(:sent_issue)), params: { newsletter: { subject: "Nope" } }
    assert_redirected_to admin_newsletter_path(newsletters(:sent_issue))
    assert_not_equal "Nope", newsletters(:sent_issue).reload.subject
  end

  test "send_now starts the send pipeline" do
    newsletter = newsletters(:draft_issue)
    assert_enqueued_with(job: SendNewsletterJob, args: [ newsletter.id ]) do
      post send_now_admin_newsletter_path(newsletter)
    end
    assert newsletter.reload.sending?
    assert_redirected_to admin_newsletter_path(newsletter)
  end

  test "send_now refuses a non-draft" do
    newsletter = newsletters(:sent_issue)
    assert_no_enqueued_jobs only: SendNewsletterJob do
      post send_now_admin_newsletter_path(newsletter)
    end
  end

  test "schedule sets scheduled_at and enqueues a delayed send" do
    newsletter = newsletters(:draft_issue)
    at = 3.days.from_now.change(usec: 0)
    assert_enqueued_with(job: SendNewsletterJob, args: [ newsletter.id ]) do
      post schedule_admin_newsletter_path(newsletter), params: { newsletter: { scheduled_at: at } }
    end
    assert newsletter.reload.scheduled?
    assert_equal at.to_i, newsletter.scheduled_at.to_i
  end

  test "schedule without a time is rejected" do
    newsletter = newsletters(:draft_issue)
    post schedule_admin_newsletter_path(newsletter), params: { newsletter: { scheduled_at: "" } }
    assert newsletter.reload.draft?
  end

  test "cancel reverts a scheduled newsletter to draft" do
    newsletter = newsletters(:scheduled_issue)
    post cancel_admin_newsletter_path(newsletter)
    assert newsletter.reload.draft?
    assert_nil newsletter.scheduled_at
  end

  test "preview renders the email body" do
    get preview_admin_newsletter_path(newsletters(:draft_issue))
    assert_response :success
    assert_match "Hello from the band", response.body
    assert_match "Email preview", response.body
  end

  test "destroy removes a non-sent newsletter" do
    assert_difference -> { Newsletter.count }, -1 do
      delete admin_newsletter_path(newsletters(:draft_issue))
    end
  end

  test "generate creates a draft and enqueues AI generation" do
    assert_difference -> { Newsletter.count }, 1 do
      assert_enqueued_with(job: GenerateNewsletterDraftJob) do
        post generate_admin_newsletters_path, params: { newsletter: { subject: "AI issue", ai_topic: "summer tour" } }
      end
    end
    newsletter = Newsletter.last
    assert newsletter.draft?
    assert_redirected_to admin_newsletter_path(newsletter)
  end

  test "generate rejects a blank subject" do
    assert_no_difference -> { Newsletter.count } do
      assert_no_enqueued_jobs only: GenerateNewsletterDraftJob do
        post generate_admin_newsletters_path, params: { newsletter: { subject: "" } }
      end
    end
    assert_response :unprocessable_entity
  end

  test "regenerate enqueues AI generation for a draft" do
    assert_enqueued_with(job: GenerateNewsletterDraftJob) do
      post regenerate_admin_newsletter_path(newsletters(:draft_issue)), params: { newsletter: { ai_topic: "merch" } }
    end
    assert_redirected_to admin_newsletter_path(newsletters(:draft_issue))
  end

  test "regenerate refuses a non-draft" do
    assert_no_enqueued_jobs only: GenerateNewsletterDraftJob do
      post regenerate_admin_newsletter_path(newsletters(:sent_issue))
    end
  end

  test "send_now is rejected when the body is blank" do
    blank = Newsletter.create!(subject: "Empty draft")
    assert_no_enqueued_jobs only: SendNewsletterJob do
      post send_now_admin_newsletter_path(blank)
    end
    assert blank.reload.draft?
  end

  test "schedule is rejected when the body is blank" do
    blank = Newsletter.create!(subject: "Empty draft")
    post schedule_admin_newsletter_path(blank), params: { newsletter: { scheduled_at: 2.days.from_now } }
    assert blank.reload.draft?
  end
end
