require "test_helper"

class Admin::VideosControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:one)) }

  # ── Auth ───────────────────────────────────────────────────────────────

  test "index requires authentication" do
    reset!
    get admin_videos_path
    assert_redirected_to new_session_path
  end

  # ── index ──────────────────────────────────────────────────────────────

  test "index renders all videos including hidden" do
    get admin_videos_path
    assert_response :success
    assert_match videos(:medicine_woman).title, response.body
    assert_match videos(:hidden_video).title,   response.body
  end

  # ── update (toggle visibility) ─────────────────────────────────────────

  test "update can hide a visible video" do
    patch admin_video_path(videos(:medicine_woman)),
          params: { video: { visible: false } }
    assert_redirected_to admin_videos_path
    assert_not videos(:medicine_woman).reload.visible?
  end

  test "update can show a hidden video" do
    patch admin_video_path(videos(:hidden_video)),
          params: { video: { visible: true } }
    assert_redirected_to admin_videos_path
    assert videos(:hidden_video).reload.visible?
  end

  # ── sync ───────────────────────────────────────────────────────────────

  test "sync runs the job and redirects with notice" do
    SyncYoutubeVideosJob.stub(:perform_now, nil) do
      post sync_admin_videos_path
    end
    assert_redirected_to admin_videos_path
    assert_match "Synced", flash[:notice]
  end

  test "sync redirects with alert when client raises an error" do
    SyncYoutubeVideosJob.stub(:perform_now, -> { raise YoutubeClient::Error, "timeout" }) do
      post sync_admin_videos_path
    end
    assert_redirected_to admin_videos_path
    assert_match "timeout", flash[:alert]
  end
end
