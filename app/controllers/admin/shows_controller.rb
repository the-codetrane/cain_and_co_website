module Admin
  class ShowsController < BaseController
    before_action :set_show, only: %i[edit update destroy toggle_featured stats]
    # Synced shows are owned by Bandsintown; editing them would be overwritten on the
    # next sync. Only manual shows can be edited or deleted here.
    before_action :require_manual_show, only: %i[edit update destroy]

    def index
      @upcoming = Show.upcoming
      @past = Show.past.limit(50)
      @configured = BandsintownClient.new.configured?
    end

    def new
      @show = Show.new(starts_at: 1.week.from_now.change(hour: 20))
    end

    def create
      @show = Show.new(show_params.merge(source: "manual", status: "active"))
      if @show.save
        redirect_to admin_shows_path, notice: "Show added."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @show.update(show_params)
        redirect_to admin_shows_path, notice: "Show updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @show.destroy
      redirect_to admin_shows_path, notice: "Show deleted.", status: :see_other
    end

    # Manual trigger of the Bandsintown sync (also runs hourly via recurring.yml).
    def sync
      SyncBandsintownEventsJob.perform_later
      redirect_to admin_shows_path, notice: "Syncing from Bandsintown — refresh in a moment."
    end

    # Featured is a local flag (survives sync), so it can be toggled on any show.
    def toggle_featured
      @show.update(featured: !@show.featured?)
      redirect_to admin_shows_path, notice: "Updated featured shows."
    end

    # Attendance and ticket sales are local fields the Bandsintown sync never
    # writes, so like featured they can be set on synced shows too. Blank clears.
    def stats
      if @show.update(params.require(:show).permit(:attendance, :ticket_sales))
        redirect_to admin_shows_path, notice: "Saved draw for #{@show.title.truncate(40)}."
      else
        redirect_to admin_shows_path, alert: @show.errors.full_messages.to_sentence
      end
    end

    private

    def set_show
      @show = Show.find(params[:id])
    end

    def require_manual_show
      return if @show.source == "manual"
      redirect_to admin_shows_path, alert: "Synced shows are managed in Bandsintown and can't be edited here."
    end

    def show_params
      params.require(:show).permit(
        :title, :description, :starts_at, :ends_at,
        :venue_name, :city, :region, :country, :bandsintown_url, :free, :attendance, :ticket_sales
      )
    end
  end
end
