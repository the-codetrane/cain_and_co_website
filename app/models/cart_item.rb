class CartItem < ApplicationRecord
  belongs_to :cart
  belongs_to :variant

  validates :quantity, numericality: { greater_than: 0 }

  def subtotal_cents
    variant.price_cents * quantity
  end
end
