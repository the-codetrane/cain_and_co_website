class Subscriber < ApplicationRecord
  # Account-free newsletter list. Double opt-in: a subscriber is "active" only once
  # they confirm and haven't unsubscribed.
  #
  # Confirmation tokens expire (opt-in must be timely); unsubscribe tokens never expire
  # (a years-old email's unsubscribe link must still work — RFC 8058 / CAN-SPAM).
  generates_token_for :confirmation, expires_in: 2.days
  generates_token_for :unsubscribe

  normalizes :email, with: ->(e) { e.to_s.strip.downcase }

  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }

  scope :confirmed, -> { where.not(confirmed_at: nil).where(unsubscribed_at: nil) }
  scope :unconfirmed, -> { where(confirmed_at: nil, unsubscribed_at: nil) }
  scope :unsubscribed, -> { where.not(unsubscribed_at: nil) }
  # The deliverable list.
  scope :active, -> { confirmed }

  def confirmed?
    confirmed_at.present? && !unsubscribed?
  end

  def unsubscribed?
    unsubscribed_at.present?
  end

  def status
    return "unsubscribed" if unsubscribed?
    confirmed_at.present? ? "confirmed" : "unconfirmed"
  end

  def confirm!
    return if confirmed_at.present?
    update!(confirmed_at: Time.current, unsubscribed_at: nil)
  end

  def unsubscribe!
    update!(unsubscribed_at: Time.current) unless unsubscribed?
  end
end
