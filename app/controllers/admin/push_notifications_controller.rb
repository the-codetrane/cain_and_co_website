module Admin
  # Manually composed push notifications, fanned out to every PushSubscription.
  class PushNotificationsController < BaseController
    def new
      @title = @body = @url = ""
    end

    def create
      @title = params[:title].to_s.strip
      @body  = params[:body].to_s.strip
      @url   = params[:url].to_s.strip.presence || "/"

      if (error = validation_error)
        flash.now[:alert] = error
        return render :new, status: :unprocessable_entity
      end

      count = PushSubscription.count
      BroadcastPushJob.perform_later(title: @title, body: @body, url: @url)
      redirect_to admin_root_path, notice: "Notification queued for #{count} #{"subscriber".pluralize(count)}."
    end

    private

    def validation_error
      return "Title and message are required." if @title.blank? || @body.blank?
      return "Title can be at most 65 characters." if @title.length > 65
      return "Message can be at most 178 characters." if @body.length > 178
      return "Link must be a path like /shows or an http(s) URL." unless valid_url?
      "Push notifications aren't configured (missing VAPID keys)." unless Rails.application.credentials.dig(:vapid, :public_key)
    end

    def valid_url?
      return true if @url.match?(%r{\A/(?!/)\S*\z})

      uri = URI.parse(@url)
      uri.is_a?(URI::HTTP) && uri.host.present?
    rescue URI::InvalidURIError
      false
    end
  end
end
