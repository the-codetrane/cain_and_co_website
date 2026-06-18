# Generates a newsletter draft body with Claude (see NewsletterDrafter) and
# streams the result into the admin page without a reload via Turbo Streams.
# The admin then edits the draft in Trix before sending.
class GenerateNewsletterDraftJob < ApplicationJob
  queue_as :default

  def perform(newsletter_id, topic: nil, drafter: NewsletterDrafter.new)
    newsletter = Newsletter.find_by(id: newsletter_id)
    return unless newsletter&.draft?

    broadcast_status(newsletter, "Generating your draft…")

    unless drafter.configured?
      return broadcast_status(newsletter, "AI drafting isn't configured yet (missing Anthropic API key).", error: true)
    end

    html = drafter.call(topic: topic)
    if html.blank?
      return broadcast_status(newsletter, "Claude returned an empty draft — try again, maybe with a more specific topic.", error: true)
    end

    newsletter.update!(body: html)
    broadcast_body(newsletter)
    broadcast_status(newsletter, "Draft ready — edit it below, then send when you're happy.")
  rescue NewsletterDrafter::Error => e
    broadcast_status(newsletter, "Couldn't generate a draft: #{e.message}", error: true)
    Rails.logger.error("[Newsletter AI] generation failed for ##{newsletter_id}: #{e.message}")
  end

  private

  def broadcast_body(newsletter)
    Turbo::StreamsChannel.broadcast_update_to(
      newsletter, target: "newsletter_body",
      partial: "admin/newsletters/body", locals: { newsletter: newsletter }
    )
  end

  def broadcast_status(newsletter, message, error: false)
    Turbo::StreamsChannel.broadcast_update_to(
      newsletter, target: "draft_status",
      partial: "admin/newsletters/draft_status", locals: { message: message, error: error }
    )
  end
end
