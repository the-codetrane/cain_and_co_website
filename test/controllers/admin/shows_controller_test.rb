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
end
