class Product < ApplicationRecord
  has_many :variants, dependent: :destroy
  has_many_attached :images

  validates :name, presence: true

  scope :published, -> { where(published: true) }
  scope :featured, -> { where(featured: true) }
  scope :by_name, -> { order(:name) }

  after_commit :broadcast_push_on_publish, on: :update

  def lowest_price_cents
    variants.minimum(:price_cents)
  end

  def in_stock?
    variants.where("stock_quantity > 0").exists?
  end

  private

  def broadcast_push_on_publish
    return unless saved_change_to_published?(from: false, to: true)
    BroadcastPushJob.perform_later(
      title: "New merch drop!",
      body: "#{name} is now available in the store.",
      url: "/products/#{id}"
    )
  end
end
