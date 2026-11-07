class User < ApplicationRecord
  PASSWORD_MIN_LENGTH = 12

  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, uniqueness: true
  # allow_nil: only checked when a password is being set, so existing logins keep working.
  validates :password, length: { minimum: PASSWORD_MIN_LENGTH }, allow_nil: true
  validate :keeps_an_admin, on: :update

  generates_token_for :password_reset, expires_in: 15.minutes do
    password_salt&.last(10)
  end

  private

  def keeps_an_admin
    return unless admin_changed?(from: true, to: false)

    errors.add(:base, "The site must keep at least one admin") unless User.where(admin: true).where.not(id: id).exists?
  end
end
