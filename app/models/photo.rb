class Photo < ApplicationRecord
  has_one_attached :image

  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :image, presence: true

  scope :published, -> { where(published: true).order(:position) }

  before_validation :assign_position, on: :create

  private

  def assign_position
    self.position ||= (Photo.maximum(:position) || 0) + 1
  end
end
