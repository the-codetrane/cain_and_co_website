class Video < ApplicationRecord
  validates :youtube_id, presence: true, uniqueness: true
  validates :title, presence: true
  validates :published_at, presence: true

  scope :visible, -> { where(visible: true).order(published_at: :desc) }

  def embed_url
    "https://www.youtube-nocookie.com/embed/#{youtube_id}"
  end
end
