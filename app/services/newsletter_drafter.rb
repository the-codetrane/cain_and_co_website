# Drafts a newsletter body with Claude (Anthropic). Given an optional admin topic
# and the band's upcoming shows, returns simple HTML suitable for the Trix /
# Action Text editor — the admin edits the result before sending.
#
# Configure the key via Rails credentials (`anthropic_api_key`) or ENV
# (ANTHROPIC_API_KEY). Like BandsintownClient, this no-ops gracefully (via
# #configured?) before a key is supplied.
class NewsletterDrafter
  MODEL = :"claude-opus-4-8"
  MAX_TOKENS = 8000

  Error = Class.new(StandardError)

  # Stable persona — kept frozen so it could be prompt-cached later. Volatile
  # context (shows, topic) goes in the user turn, not here.
  PERSONA = <<~PROMPT.freeze
    You are the copywriter for Cain & Co., an independent band, writing their
    monthly email newsletter to fans.

    Voice: warm and personal — sincere and conversational, like the band writing
    to friends. Concise; no filler, no hype, no clichés. First person plural ("we").

    Output rules:
    - Return ONLY the email body as simple HTML. No <html>, <head>, <body>, or
      <style> tags, no markdown, no code fences.
    - Use only <p>, <h2>, <a href>, <ul>, <li>, <strong>, and <em>.
    - Open with a short, friendly greeting paragraph.
    - If shows are provided, include a "Shows" section (<h2>) listing each with
      its date, venue, and city, and link the ticket URL when present.
    - End with a brief, genuine sign-off.
    - Do not invent shows, dates, releases, or links that aren't given to you.
  PROMPT

  NO_KEY = Object.new.freeze
  private_constant :NO_KEY

  def initialize(client: nil, api_key: NO_KEY)
    @client = client
    @api_key = api_key
  end

  # True once an API key is available. Does not build the client.
  def configured?
    api_key.present?
  end

  # Returns the draft body as an HTML string.
  def call(topic: nil, shows: Show.upcoming.limit(8))
    raise Error, "Anthropic API key is not configured" unless configured?

    message = client.messages.create(
      model: MODEL,
      max_tokens: MAX_TOKENS,
      thinking: { type: :adaptive },
      output_config: { effort: :medium },
      system_: PERSONA,
      messages: [ { role: "user", content: user_prompt(topic:, shows:) } ]
    )
    extract_text(message)
  rescue Anthropic::Errors::APIStatusError, Anthropic::Errors::APIError => e
    raise Error, "Claude request failed: #{e.message}"
  end

  private

  def client
    @client ||= Anthropic::Client.new(api_key: api_key)
  end

  def api_key
    return @api_key unless @api_key.equal?(NO_KEY)
    Rails.application.credentials.anthropic_api_key || ENV["ANTHROPIC_API_KEY"]
  end

  def user_prompt(topic:, shows:)
    parts = []
    parts << if topic.present?
      "Write this month's newsletter. The band wants it to focus on: #{topic.to_s.strip}."
    else
      "Write this month's newsletter with a friendly check-in and whatever's coming up."
    end
    parts << shows_context(shows)
    parts.join("\n\n")
  end

  def shows_context(shows)
    shows = shows.to_a
    return "There are no upcoming shows on the calendar right now." if shows.empty?

    lines = shows.map do |show|
      bits = [ show.starts_at&.to_fs(:long), show.venue, show.location.presence ].compact
      ticket = show.ticket_url
      bits << "tickets: #{ticket}" if ticket.present?
      "- #{show.title} (#{bits.join(' · ')})"
    end
    "Upcoming shows:\n#{lines.join("\n")}"
  end

  def extract_text(message)
    message.content.filter_map { |block| block.text if block.type == :text }.join("\n").strip
  end
end
