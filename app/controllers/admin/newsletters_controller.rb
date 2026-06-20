module Admin
  class NewslettersController < BaseController
    before_action :set_newsletter, except: %i[index new create generate]
    before_action :require_draft_status, only: %i[edit update]

    def index
      @newsletters = Newsletter.recent
    end

    def show
      @stats = @newsletter.delivery_stats
    end

    def new
      @newsletter = Newsletter.new
    end

    def create
      @newsletter = Newsletter.new(newsletter_params)
      if @newsletter.save
        redirect_to admin_newsletter_path(@newsletter), notice: "Draft saved."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @newsletter.update(newsletter_params)
        redirect_to admin_newsletter_path(@newsletter), notice: "Draft updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @newsletter.sending? || @newsletter.sent?
        redirect_to admin_newsletter_path(@newsletter), alert: "Sending or sent newsletters cannot be deleted."
      else
        @newsletter.destroy
        redirect_to admin_newsletters_path, notice: "Newsletter deleted.", status: :see_other
      end
    end

    # In-admin render of the email body as subscribers will see it.
    def preview
      render layout: "mailer_preview"
    end

    # Create a draft from a subject + topic and kick off AI generation ("Start with AI").
    def generate
      @newsletter = Newsletter.new(subject: params.dig(:newsletter, :subject))
      if @newsletter.save
        GenerateNewsletterDraftJob.perform_later(@newsletter.id, topic: ai_topic)
        redirect_to admin_newsletter_path(@newsletter),
                    notice: "Generating your draft… this page will update automatically."
      else
        @newsletter_ai_topic = ai_topic
        render :new, status: :unprocessable_entity
      end
    end

    # Re-run AI generation for an existing draft.
    def regenerate
      return reject_unsendable unless @newsletter.draft?

      GenerateNewsletterDraftJob.perform_later(@newsletter.id, topic: ai_topic)
      redirect_to admin_newsletter_path(@newsletter),
                  notice: "Regenerating your draft… this page will update automatically."
    end

    def send_now
      return reject_unsendable unless @newsletter.sendable?
      return reject_blank_body if @newsletter.body.blank?

      @newsletter.update!(status: :sending)
      SendNewsletterJob.perform_later(@newsletter.id)
      redirect_to admin_newsletter_path(@newsletter),
                  notice: "Sending to #{Subscriber.active.count} subscribers."
    end

    def schedule
      return reject_unsendable unless @newsletter.sendable?
      return reject_blank_body if @newsletter.body.blank?

      if @newsletter.update(status: :scheduled, scheduled_at: params.dig(:newsletter, :scheduled_at))
        SendNewsletterJob.set(wait_until: @newsletter.scheduled_at).perform_later(@newsletter.id)
        redirect_to admin_newsletter_path(@newsletter),
                    notice: "Scheduled for #{@newsletter.scheduled_at.to_fs(:long)}."
      else
        redirect_to admin_newsletter_path(@newsletter),
                    alert: @newsletter.errors.full_messages.to_sentence.presence || "Could not schedule."
      end
    end

    # Revert a scheduled newsletter to draft. The already-enqueued SendNewsletterJob
    # becomes a no-op when it fires (it only runs for scheduled/sending newsletters).
    def cancel
      return redirect_to admin_newsletter_path(@newsletter), alert: "Nothing to cancel." unless @newsletter.scheduled?

      @newsletter.update!(status: :draft, scheduled_at: nil)
      redirect_to admin_newsletter_path(@newsletter), notice: "Schedule canceled — back to draft."
    end

    private

    def set_newsletter
      @newsletter = Newsletter.find(params[:id])
    end

    def newsletter_params
      params.require(:newsletter).permit(:subject, :body)
    end

    # The AI topic is a transient hint for the drafter, not a persisted column.
    def ai_topic
      params.dig(:newsletter, :ai_topic)
    end

    def reject_unsendable
      redirect_to admin_newsletter_path(@newsletter),
                  alert: "This newsletter has already been sent or scheduled."
    end

    def reject_blank_body
      redirect_to admin_newsletter_path(@newsletter),
                  alert: "Add some content before sending — write it or generate a draft with AI."
    end

    def require_draft_status
      redirect_to admin_newsletter_path(@newsletter), alert: "Only drafts can be edited." unless @newsletter.draft?
    end
  end
end
