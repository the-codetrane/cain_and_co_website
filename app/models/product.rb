class Product < ApplicationRecord
  has_many :variants, dependent: :destroy
  has_many_attached :images

  validates :name, presence: true

  scope :published, -> { where(published: true) }
  scope :featured, -> { where(featured: true) }
  scope :by_name, -> { order(:name) }

  def lowest_price_cents
    variants.minimum(:price_cents)
  end

  def in_stock?
    variants.where("stock_quantity > 0").exists?
  end
end
