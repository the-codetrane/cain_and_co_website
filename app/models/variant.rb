class Variant < ApplicationRecord
  # The size palette offered by the admin "size buttons" picker, in the order sizes
  # should be displayed. A variant is just a named option row — nothing in the schema
  # forces a variant to be a size — but when its name matches one of these it gets a
  # position from this list so S/M/L/XL always render in the right order regardless of
  # the order they were created in.
  SIZES = [ "XS", "S", "M", "L", "XL", "2XL", "3XL", "One Size" ].freeze

  # Names people commonly type by hand, mapped onto the canonical palette so
  # "Small" and "S" sort to the same slot.
  SIZE_ALIASES = {
    "extra small" => "XS", "xsmall" => "XS", "x-small" => "XS",
    "small" => "S",
    "medium" => "M", "med" => "M",
    "large" => "L",
    "extra large" => "XL", "xlarge" => "XL", "x-large" => "XL",
    "xxl" => "2XL", "xx-large" => "2XL", "2x" => "2XL",
    "xxxl" => "3XL", "xxx-large" => "3XL", "3x" => "3XL",
    "onesize" => "One Size", "os" => "One Size"
  }.freeze

  # Positions are spaced out so a non-size variant appended later (see #assign_position)
  # never collides with a size slot.
  SIZE_POSITION_STEP = 10

  # Shipping weight to assume for a variant nobody has weighed yet — roughly a
  # printed tee in a poly mailer. ShippingRate tiers on total cart weight, so a
  # literal 0 would ship a whole order for the lightest rate.
  DEFAULT_WEIGHT_OZ = 8

  belongs_to :product
  has_many :cart_items, dependent: :destroy
  has_many :order_items, dependent: :nullify

  validates :name, presence: true
  validates :name, uniqueness: { scope: :product_id, case_sensitive: false,
                                 message: "is already an option on this product" }
  validates :price_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :stock_quantity, numericality: { greater_than_or_equal_to: 0 }
  validates :weight_oz, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  before_validation :normalize_sku
  before_validation :assign_position
  validates :sku, uniqueness: true, allow_nil: true

  scope :ordered, -> { order(:position, :id) }
  scope :in_stock, -> { where("stock_quantity > 0") }

  # The canonical size this variant's name refers to, or nil if it isn't a size.
  def self.canonical_size(name)
    key = name.to_s.strip
    return nil if key.blank?
    SIZES.find { |size| size.casecmp?(key) } || SIZES.find { |size| size == SIZE_ALIASES[key.downcase] }
  end

  def price_dollars
    price_cents / 100.0
  end

  def in_stock?
    stock_quantity > 0
  end

  # Applies delta in a single UPDATE so a hand count can't overwrite a sale that
  # OrderPaymentSync records at the same moment. Floors at zero, as that sync does.
  def adjust_stock(delta)
    self.class.where(id: id).update_all(
      [ "stock_quantity = MAX(stock_quantity + ?, 0), updated_at = ?", delta, Time.current ]
    )
    reload
  end

  # The weight ShippingRate should bill for. An unweighed variant (0) falls back to
  # DEFAULT_WEIGHT_OZ rather than adding nothing to the parcel.
  def shipping_weight_oz
    weight_oz.to_i.positive? ? weight_oz : DEFAULT_WEIGHT_OZ
  end

  def weighed?
    weight_oz.to_i.positive?
  end

  def size?
    self.class.canonical_size(name).present?
  end

  def display_name
    [ product.name, name ].join(" — ")
  end

  private

  def normalize_sku
    self.sku = nil if sku.blank?
  end

  # Sizes take their slot from SIZES; anything else lands after every size so a
  # hand-entered option ("Black", "Signed") doesn't interleave with the size run.
  # An explicitly-set position (the admin form exposes one) always wins.
  def assign_position
    return unless position.to_i.zero?

    index = SIZES.index(self.class.canonical_size(name))
    self.position =
      if index
        (index + 1) * SIZE_POSITION_STEP
      else
        siblings = product ? product.variants.where.not(id: id) : Variant.none
        [ siblings.maximum(:position).to_i + 1, (SIZES.size + 1) * SIZE_POSITION_STEP ].max
      end
  end
end
