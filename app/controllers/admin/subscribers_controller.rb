require "csv"

module Admin
  class SubscribersController < BaseController
    before_action :set_subscriber, only: %i[destroy resend_confirmation]

    def index
      @counts = {
        total: Subscriber.count,
        confirmed: Subscriber.confirmed.count,
        unconfirmed: Subscriber.unconfirmed.count,
        unsubscribed: Subscriber.unsubscribed.count
      }

      @query = params[:q].to_s.strip
      scope = Subscriber.order(created_at: :desc)
      scope = scope.where("email LIKE ?", "%#{Subscriber.sanitize_sql_like(@query)}%") if @query.present?

      respond_to do |format|
        format.html { @subscribers = scope }
        format.csv do
          send_data subscribers_csv(scope.reorder(:created_at)),
                    filename: "subscribers-#{Time.current.strftime('%Y%m%d')}.csv",
                    type: "text/csv"
        end
      end
    end

    def new
      @subscriber = Subscriber.new
    end

    def create
      @subscriber = Subscriber.new(subscriber_params)
      # Admin-added subscribers are confirmed immediately — the admin vouches for them.
      @subscriber.confirmed_at ||= Time.current

      if @subscriber.save
        redirect_to admin_subscribers_path, notice: "Subscriber added."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      @subscriber.destroy
      redirect_to admin_subscribers_path, notice: "Subscriber removed.", status: :see_other
    end

    def resend_confirmation
      if @subscriber.confirmed?
        redirect_to admin_subscribers_path, notice: "#{@subscriber.email} is already confirmed."
      else
        SubscriberMailer.with(subscriber: @subscriber).confirmation.deliver_later
        redirect_to admin_subscribers_path, notice: "Confirmation email resent to #{@subscriber.email}."
      end
    end

    private

    def set_subscriber
      @subscriber = Subscriber.find(params[:id])
    end

    def subscriber_params
      params.require(:subscriber).permit(:email)
    end

    def subscribers_csv(scope)
      CSV.generate do |csv|
        csv << %w[email status confirmed_at unsubscribed_at created_at]
        scope.each do |s|
          csv << [ s.email, s.status, s.confirmed_at, s.unsubscribed_at, s.created_at ]
        end
      end
    end
  end
end
