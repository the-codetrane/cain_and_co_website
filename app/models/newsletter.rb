class Newsletter < ApplicationRecord
  # Admin-composed issue of the monthly newsletter. The body is rich text (Trix /
  # Action Text); see app/views/newsletter_mailer/issue.html.erb for how it renders
  # into the email.
  has_rich_text :body
  has_many :deliveries, dependent: :destroy

  # draft     — being composed, never sent
  # scheduled — queued to send at scheduled_at
  # sending   — send pipeline is fanning out / draining deliveries
  # sent       — every recipient has a terminal Delivery (sent or failed)
  enum :status, { draft: 0, scheduled: 1, sending: 2, sent: 3 }, default: :draft

  validates :subject, presence: true
  # Body is optional while drafting (AI generation fills it in asynchronously),
  # but required once the newsletter leaves draft for scheduling/sending.
  validate  :body_present, unless: :draft?
  validates :scheduled_at, presence: true, if: :scheduled?

  scope :recent, -> { order(created_at: :desc) }

  # A newsletter can only be (re)sent or scheduled while it is still a draft —
  # guards against double-sending from a stale form or a duplicate click.
  def sendable?
    draft?
  end

  # Snapshot the deliverable list into pending Delivery rows. Called once when a
  # send starts; idempotent (the unique index + ON CONFLICT DO NOTHING mean a
  # re-run never duplicates and never picks up subscribers added mid-send).
  def build_deliveries!
    now = Time.current
    rows = Subscriber.active
                     .where.not(id: deliveries.select(:subscriber_id))
                     .pluck(:id)
                     .map { |sid| { newsletter_id: id, subscriber_id: sid, status: Delivery.statuses[:pending], created_at: now, updated_at: now } }
    Delivery.insert_all(rows, unique_by: %i[newsletter_id subscriber_id]) if rows.any?
  end

  # Progress counters for the admin UI, computed in one grouped query.
  def delivery_stats
    counts = deliveries.group(:status).count
    {
      total: counts.values.sum,
      sent: counts["sent"].to_i,
      failed: counts["failed"].to_i,
      pending: counts["pending"].to_i
    }
  end

  private

  def body_present
    errors.add(:body, "can't be blank") if body.blank?
  end
end
