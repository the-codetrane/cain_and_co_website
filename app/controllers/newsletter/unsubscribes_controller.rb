module Newsletter
  # One-click unsubscribe (RFC 8058). A GET shows a confirmation page; the POST
  # actually unsubscribes. Mailbox providers issue the POST automatically via the
  # List-Unsubscribe-Post header, so CSRF protection is skipped for it. The token
  # never expires — a years-old email's unsubscribe link must still work.
  class UnsubscribesController < ApplicationController
    skip_forgery_protection only: :create

    before_action :set_subscriber

    def show
      render :invalid_token, status: :unprocessable_entity unless @subscriber
    end

    def create
      @subscriber&.unsubscribe!
      render :unsubscribed
    end

    private

    def set_subscriber
      @subscriber = Subscriber.find_by_token_for(:unsubscribe, params[:token])
    end
  end
end
