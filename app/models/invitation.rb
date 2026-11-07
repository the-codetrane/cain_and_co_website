class Invitation < ApplicationRecord
  # A pending invite to create an account. The row exists only until it's accepted:
  # accepting creates the User and destroys the invitation, which is what makes the
  # link single-use. Possession of the emailed link is the proof of email ownership.
  EXPIRES_IN = 7.days

  # Keyed on sent_at so that re-inviting an address invalidates its earlier link.
  generates_token_for :acceptance, expires_in: EXPIRES_IN do
    sent_at.iso8601(6)
  end

  normalizes :email, with: ->(e) { e.to_s.strip.downcase }

  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validate :email_has_no_account

  # Inviting an address that already has a pending or expired invite refreshes it
  # rather than failing, so a lapsed invite can always be sent again.
  def self.issue(email:, admin: false)
    find_or_initialize_by(email: email).tap do |invitation|
      invitation.update(admin: admin, sent_at: Time.current)
    end
  end

  def expires_at
    sent_at + EXPIRES_IN
  end

  def expired?
    expires_at.past?
  end

  # Returns the User, persisted on success or carrying validation errors on failure.
  def accept(credentials)
    user = User.new(credentials.to_h.merge(email_address: email, admin: admin))
    transaction { destroy! if user.save }
    user
  end

  private

  def email_has_no_account
    errors.add(:email, "already has an account") if User.exists?(email_address: email)
  end
end
