class Order < ApplicationRecord
  STATUSES = %w[pending paid fulfilled canceled].freeze

  has_many :order_items, dependent: :destroy

  validates :status, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: "pending") }
  scope :paid, -> { where(status: "paid") }
  scope :fulfilled, -> { where(status: "fulfilled") }
  scope :needs_fulfillment, -> { where(status: "paid").order(created_at: :asc) }
  scope :recent, -> { order(created_at: :desc) }

  def paid?    = status == "paid"
  def pending? = status == "pending"
  def fulfilled? = status == "fulfilled"
  def canceled? = status == "canceled"

  def total_dollars
    total_cents / 100.0
  end

  def shipping_address
    [ shipping_name, shipping_address1, shipping_address2,
     shipping_city, shipping_state, shipping_zip, shipping_country ]
      .compact_blank.join(", ")
  end
end
