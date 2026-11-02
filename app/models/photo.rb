class Photo < ApplicationRecord
  has_one_attached :image, dependent: :purge_later

  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :image, presence: true

  scope :published, -> { where(published: true).order(:position) }
  # Press photos hand-picked for the booker-facing /epk page.
  scope :epk, -> { published.where(epk: true) }

  before_validation :assign_position, on: :create

  # What to hand `image_tag`. On a public service (DigitalOcean Spaces in
  # production) this is the object's own URL, so browsers fetch it straight
  # from Spaces instead of bouncing through the app's redirect route. On the
  # Disk service used in development and test there is no public URL, so fall
  # back to the attachment and let Rails build its usual route.
  def image_src
    return nil unless image.attached?

    image.blob.service.public? ? image.url : image
  end

  private

  def assign_position
    self.position ||= (Photo.maximum(:position) || 0) + 1
  end
end
