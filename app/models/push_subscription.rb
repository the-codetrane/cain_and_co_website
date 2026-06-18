class PushSubscription < ApplicationRecord
  validates :endpoint, :p256dh_key, :auth_key, presence: true
  validates :endpoint, uniqueness: true
end
