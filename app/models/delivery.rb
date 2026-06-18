class Delivery < ApplicationRecord
  # One newsletter sent to one subscriber. The (newsletter, subscriber) unique
  # index plus the pending -> sent/failed state machine make the send pipeline
  # idempotent: a retried job that finds a non-pending row does nothing.
  belongs_to :newsletter
  belongs_to :subscriber

  enum :status, { pending: 0, sent: 1, failed: 2 }, default: :pending

  # Deliveries marked sent today, used to enforce the provider's daily cap.
  scope :sent_today, -> { sent.where(sent_at: Time.current.all_day) }

  def mark_sent!
    update!(status: :sent, sent_at: Time.current, error: nil)
  end

  def mark_failed!(error)
    update!(status: :failed, error: error.to_s.truncate(1000))
  end
end
