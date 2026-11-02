module Admin
  class VideosController < BaseController
    before_action :set_video, only: :update

    def index
      @videos = Video.order(published_at: :desc)
    end

    def update
      @video.update!(params.require(:video).permit(:visible, :epk))
      redirect_to admin_videos_path, notice: "#{@video.title.truncate(40)} updated."
    end

    def sync
      SyncYoutubeVideosJob.perform_now
      redirect_to admin_videos_path, notice: "Synced from YouTube."
    rescue YoutubeClient::Error => e
      redirect_to admin_videos_path, alert: "Sync failed: #{e.message}"
    end

    private

    def set_video
      @video = Video.find(params[:id])
    end
  end
end
