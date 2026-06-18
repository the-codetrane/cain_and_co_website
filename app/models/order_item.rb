class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :variant, optional: true

  validates :variant_name, :unit_price_cents, :quantity, presence: true
  validates :quantity, numericality: { greater_than: 0 }

  def subtotal_cents
    unit_price_cents * quantity
  end
end
