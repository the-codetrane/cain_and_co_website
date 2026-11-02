class Video < ApplicationRecord
  validates :youtube_id, presence: true, uniqueness: true
  validates :title, presence: true
  validates :published_at, presence: true

  scope :visible, -> { where(visible: true).order(published_at: :desc) }
  # Live clips hand-picked for the booker-facing /epk page.
  scope :epk, -> { visible.where(epk: true) }

  # Title for captions. YouTube cuts long titles (common on Shorts, whose title is
  # the caption) with a trailing "…"; drop the cut-off fragment back to the last
  # full sentence so captions don't end mid-thought.
  def display_title
    return title unless title.end_with?("…", "...")

    full_sentence = title[/\A.*[.!?](?=\s)/]
    full_sentence.presence || title.sub(/\s*[—–-]?\s*(…|\.\.\.)\z/, "")
  end

  def embed_url
    "https://www.youtube-nocookie.com/embed/#{youtube_id}"
  end
end
