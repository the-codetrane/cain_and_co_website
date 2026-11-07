class Product < ApplicationRecord
  # Folder in the shared Spaces bucket. Objects left in the bucket root get filed
  # away by hand, and a moved object 404s because its blob still holds the old key.
  IMAGE_FOLDER = "Product Images"

  IMAGE_VARIANTS = %i[ card hero thumb cart ].freeze

  # Everything MediaSource reads to link a variant directly, for use in `includes`.
  IMAGE_PRELOAD = { images_attachments: { blob: { variant_records: { image_attachment: :blob } } } }.freeze

  has_many :variants, -> { ordered }, dependent: :destroy, inverse_of: :product
  has_many_attached :images do |attachable|
    attachable.variant :card, resize_to_fill: [ 400, 400 ], preprocessed: true
    attachable.variant :hero, resize_to_fill: [ 600, 600 ], preprocessed: true
    attachable.variant :thumb, resize_to_fill: [ 100, 100 ], preprocessed: true
    attachable.variant :cart, resize_to_fill: [ 80, 80 ], preprocessed: true
  end

  validates :name, presence: true

  scope :published, -> { where(published: true) }
  scope :featured, -> { where(featured: true) }
  scope :by_name, -> { order(:name) }
  scope :with_image_variants, -> { includes(IMAGE_PRELOAD) }

  after_commit :broadcast_push_on_publish, on: :update

  # An attachable for `images` that stores the upload inside IMAGE_FOLDER.
  def self.image_attachable(upload)
    {
      io: upload.tempfile,
      filename: upload.original_filename,
      content_type: upload.content_type,
      key: "#{IMAGE_FOLDER}/#{SecureRandom.base36(ActiveStorage::Blob::MINIMUM_TOKEN_LENGTH)}"
    }
  end

  def lowest_price_cents
    variants.map(&:price_cents).min
  end

  def in_stock?
    variants.any?(&:in_stock?)
  end

  # Every size already defined on this product, so the admin picker can show which
  # of Variant::SIZES are still available to add.
  def existing_size_names
    variants.filter_map { |variant| Variant.canonical_size(variant.name) }
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
