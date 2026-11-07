require "test_helper"

class Admin::ShowsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:one)) }

  test "index requires authentication" do
    reset!  # drop the signed-in session
    get admin_shows_path
    assert_redirected_to new_session_path
  end

  test "index lists shows when signed in" do
    get admin_shows_path
    assert_response :success
  end

  test "sync enqueues the sync job" do
    assert_enqueued_with(job: SyncBandsintownEventsJob) do
      post sync_admin_shows_path
    end
    assert_redirected_to admin_shows_path
  end

  test "toggle_featured flips the flag" do
    show = shows(:manual_upcoming)
    assert_not show.featured?
    patch toggle_featured_admin_show_path(show)
    assert show.reload.featured?
  end

  test "can create a manual show" do
    assert_difference -> { Show.manual.count }, 1 do
      post admin_shows_path, params: { show: {
        title: "House show", starts_at: 2.weeks.from_now.strftime("%Y-%m-%dT%H:%M"),
        venue_name: "Someone's garage", city: "Tucson"
      } }
    end
    assert_redirected_to admin_shows_path
    assert_equal "manual", Show.find_by(title: "House show").source
  end

  test "synced shows cannot be edited" do
    synced = shows(:upcoming)
    get edit_admin_show_path(synced)
    assert_redirected_to admin_shows_path
    assert_match(/managed in Bandsintown/, flash[:alert])
  end

  test "manual shows can be deleted" do
    show = shows(:manual_upcoming)
    assert_difference -> { Show.count }, -1 do
      delete admin_show_path(show)
    end
  end

  test "attendance can be recorded on a synced show" do
    show = shows(:past)
    patch annotate_admin_show_path(show), params: { show: { attendance: "85" } }
    assert_redirected_to admin_shows_path
    assert_equal 85, show.reload.attendance
  end

  test "blank attendance clears it" do
    show = shows(:past)
    show.update!(attendance: 40)
    patch annotate_admin_show_path(show), params: { show: { attendance: "" } }
    assert_nil show.reload.attendance
  end

  test "ticket sales are entered in dollars and stored in cents" do
    show = shows(:past)
    patch annotate_admin_show_path(show), params: { show: { attendance: "40", ticket_sales: "1,000" } }
    assert_redirected_to admin_shows_path
    show.reload
    assert_equal 40, show.attendance
    assert_equal 100_000, show.ticket_sales_cents
  end

  test "non-numeric ticket sales are rejected, not stored as zero" do
    show = shows(:past)
    patch annotate_admin_show_path(show), params: { show: { ticket_sales: "lots" } }
    assert flash[:alert].present?
    assert_nil show.reload.ticket_sales_cents
  end

  test "negative attendance is rejected" do
    show = shows(:past)
    patch annotate_admin_show_path(show), params: { show: { attendance: "-3" } }
    assert_redirected_to admin_shows_path
    assert_nil show.reload.attendance
    assert flash[:alert].present?
  end

  test "sync does not overwrite recorded attendance" do
    show = shows(:past)
    show.update!(attendance: 85)
    Show.from_bandsintown("id" => show.bandsintown_id, "datetime" => show.starts_at.iso8601,
                          "title" => show.title, "venue" => { "name" => show.venue_name })
    assert_equal 85, show.reload.attendance
  end

  test "venue override can be set on a synced show and survives a sync" do
    show = shows(:upcoming)
    patch annotate_admin_show_path(show), params: { show: { venue_override: "Eagle's 34" } }
    assert_redirected_to admin_shows_path
    assert_equal "Eagle's 34", show.reload.venue_override

    Show.from_bandsintown("id" => show.bandsintown_id, "datetime" => show.starts_at.iso8601,
                          "title" => show.title, "venue" => { "name" => show.title })
    assert_equal "Eagle's 34", show.reload.venue
  end

  test "attendance fields only appear on played shows" do
    get admin_shows_path
    assert_select "form[action=?] input[name='show[attendance]']", annotate_admin_show_path(shows(:past))
    assert_select "form[action=?] input[name='show[attendance]']", annotate_admin_show_path(shows(:upcoming)), count: 0
    assert_select "form[action=?] input[name='show[venue_override]']", annotate_admin_show_path(shows(:upcoming))
  end

  test "inline save over Turbo replaces only that show's row" do
    show = shows(:past)
    patch annotate_admin_show_path(show), params: { show: { attendance: "55" } }, as: :turbo_stream
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[action=replace][target=?]", "show_#{show.id}", count: 1
    assert_select "turbo-stream template input[name='show[attendance]'][value='55']"
    assert_select "turbo-stream template [role=status]", "Saved."
    assert_equal 55, show.reload.attendance
  end

  test "invalid inline save re-renders the row with the error and keeps the input" do
    show = shows(:past)
    patch annotate_admin_show_path(show), params: { show: { attendance: "-3" } }, as: :turbo_stream
    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=replace][target=?]", "show_#{show.id}"
    assert_select "turbo-stream template [role=alert]", /Attendance must be greater than or equal to 0/
    assert_select "turbo-stream template input[name='show[attendance]'][value='-3']"
    assert_nil show.reload.attendance
  end

  test "featured toggle over Turbo replaces only that row" do
    show = shows(:manual_upcoming)
    patch toggle_featured_admin_show_path(show), as: :turbo_stream
    assert_select "turbo-stream[action=replace][target=?]", "show_#{show.id}"
    assert_select "turbo-stream template button", text: "★ Featured"
    assert show.reload.featured?
  end

  test "index rows carry dom ids for stream targets" do
    get admin_shows_path
    assert_select "div[id=?]", "show_#{shows(:past).id}"
  end
end
