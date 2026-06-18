class Variant < ApplicationRecord
  belongs_to :product
  has_many :cart_items, dependent: :destroy
  has_many :order_items, dependent: :nullify

  validates :name, presence: true
  validates :price_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :stock_quantity, numericality: { greater_than_or_equal_to: 0 }
  validates :sku, uniqueness: true, allow_blank: true

  def price_dollars
    price_cents / 100.0
  end

  def in_stock?
    stock_quantity > 0
  end

  def display_name
    [ product.name, name ].join(" — ")
  end
end
