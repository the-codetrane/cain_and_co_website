class Cart < ApplicationRecord
  has_many :cart_items, dependent: :destroy
  has_many :variants, through: :cart_items

  before_create :generate_token

  def total_cents
    cart_items.sum { |item| item.variant.price_cents * item.quantity }
  end

  def item_count
    cart_items.sum(:quantity)
  end

  # Summed item weight only — ShippingRate adds the packaging on top.
  def shipping_weight_oz
    cart_items.sum { |item| item.variant.shipping_weight_oz * item.quantity }
  end

  def empty?
    cart_items.empty?
  end

  def add_variant(variant, quantity: 1)
    item = cart_items.find_or_initialize_by(variant: variant)
    item.quantity += quantity if item.persisted?
    item.quantity = quantity unless item.persisted?
    item.save!
    item
  end

  private

  def generate_token
    self.token = SecureRandom.urlsafe_base64(32)
  end
end
