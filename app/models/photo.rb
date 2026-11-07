class Photo < ApplicationRecord
  has_one_attached :image, dependent: :purge_later do |attachable|
    attachable.variant :carousel, resize_to_limit: [ 1600, 1600 ], format: :webp, preprocessed: :published?
    attachable.variant :press_lead, resize_to_limit: [ 1600, 1600 ], preprocessed: :epk?
    attachable.variant :press_thumb, resize_to_limit: [ 800, 800 ], preprocessed: :epk?
  end

  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :image, presence: true

  scope :published, -> { where(published: true).order(:position) }
  # Press photos hand-picked for the booker-facing /epk page. Independent of
  # `published` (the public /about gallery): a press photo may be one the band
  # wants bookers to download but not show in the gallery.
  scope :epk, -> { where(epk: true).order(:position) }
  scope :with_image_variants, -> { includes(image_attachment: { blob: { variant_records: { image_attachment: :blob } } }) }

  before_validation :assign_position, on: :create

  # The full-size image for `image_tag`.
  def image_src
    MediaSource.for(image) if image.attached?
  end

  # A named variant, or the original for a format that can't be resized, so one odd
  # upload can't take down the page showing it.
  def display(variant_name)
    image.variable? ? image.variant(variant_name) : image
  end

  private

  def assign_position
    self.position ||= (Photo.maximum(:position) || 0) + 1
  end
end
