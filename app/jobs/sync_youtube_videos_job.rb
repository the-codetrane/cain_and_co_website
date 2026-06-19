class SyncYoutubeVideosJob < ApplicationJob
  queue_as :default

  retry_on YoutubeClient::Error, wait: :polynomially_longer, attempts: 3

  def perform(client: YoutubeClient.new)
    videos = client.videos

    if videos.empty?
      Rails.logger.info("[YouTube] feed returned no entries — skipping")
      return
    end

    synced = 0
    videos.each do |attrs|
      video = Video.find_or_initialize_by(youtube_id: attrs[:youtube_id])
      video.assign_attributes(
        title:         attrs[:title],
        thumbnail_url: attrs[:thumbnail_url],
        published_at:  attrs[:published_at],
        short:         attrs[:short]
      )
      video.save!
      synced += 1
    end

    Rails.logger.info("[YouTube] synced #{synced} video(s)")
  end
end
