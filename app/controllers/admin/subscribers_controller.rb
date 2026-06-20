require "csv"

module Admin
  class SubscribersController < BaseController
    before_action :set_subscriber, only: %i[destroy resend_confirmation]

    def index
      raw = Subscriber.group(
        Arel.sql("CASE WHEN unsubscribed_at IS NOT NULL THEN 'unsubscribed' WHEN confirmed_at IS NOT NULL THEN 'confirmed' ELSE 'unconfirmed' END")
      ).count
      @counts = {
        confirmed: raw["confirmed"].to_i,
        unconfirmed: raw["unconfirmed"].to_i,
        unsubscribed: raw["unsubscribed"].to_i
      }
      @counts[:total] = @counts.values.sum

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

    def import
      return unless request.post?

      unless params[:csv_file].present?
        flash.now[:alert] = "Please choose a CSV file."
        render :import, status: :unprocessable_entity and return
      end

      results = import_csv(params[:csv_file])
      notice = "Imported #{results[:imported]} subscriber#{"s" unless results[:imported] == 1}."
      notice += " #{results[:skipped]} already existed." if results[:skipped] > 0
      notice += " #{results[:invalid]} invalid." if results[:invalid] > 0
      redirect_to admin_subscribers_path, notice: notice
    rescue ArgumentError => e
      flash.now[:alert] = e.message
      render :import, status: :unprocessable_entity
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

    def import_csv(file)
      results = { imported: 0, skipped: 0, invalid: 0 }
      csv = CSV.parse(file.read, headers: true, header_converters: :symbol)
      email_col = csv.headers.find { |h| h.to_s.strip.downcase.include?("email") }

      raise ArgumentError, "No email column found" unless email_col

      csv.each do |row|
        email = row[email_col].to_s.strip.downcase
        next results[:invalid] += 1 if email.blank? || email !~ URI::MailTo::EMAIL_REGEXP

        if Subscriber.exists?(email: email)
          results[:skipped] += 1
        else
          Subscriber.create!(email: email, confirmed_at: Time.current)
          results[:imported] += 1
        end
      rescue ActiveRecord::RecordInvalid
        results[:invalid] += 1
      end
      results
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
