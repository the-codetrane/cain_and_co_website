require "test_helper"

class Admin::ShowsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(User.take) }

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
    patch stats_admin_show_path(show), params: { show: { attendance: "85" } }
    assert_redirected_to admin_shows_path
    assert_equal 85, show.reload.attendance
  end

  test "blank attendance clears it" do
    show = shows(:past)
    show.update!(attendance: 40)
    patch stats_admin_show_path(show), params: { show: { attendance: "" } }
    assert_nil show.reload.attendance
  end

  test "ticket sales are entered in dollars and stored in cents" do
    show = shows(:past)
    patch stats_admin_show_path(show), params: { show: { attendance: "40", ticket_sales: "1,000" } }
    assert_redirected_to admin_shows_path
    show.reload
    assert_equal 40, show.attendance
    assert_equal 100_000, show.ticket_sales_cents
  end

  test "non-numeric ticket sales are rejected, not stored as zero" do
    show = shows(:past)
    patch stats_admin_show_path(show), params: { show: { ticket_sales: "lots" } }
    assert flash[:alert].present?
    assert_nil show.reload.ticket_sales_cents
  end

  test "negative attendance is rejected" do
    show = shows(:past)
    patch stats_admin_show_path(show), params: { show: { attendance: "-3" } }
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
end
