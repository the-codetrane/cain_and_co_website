class Video < ApplicationRecord
  validates :youtube_id, presence: true, uniqueness: true
  validates :title, presence: true
  validates :published_at, presence: true

  scope :visible, -> { where(visible: true).order(published_at: :desc) }
  # Live clips hand-picked for the booker-facing /epk page.
  scope :epk, -> { visible.where(epk: true) }

  def embed_url
    "https://www.youtube-nocookie.com/embed/#{youtube_id}"
  end
end
