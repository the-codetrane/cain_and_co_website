require "test_helper"

class Admin::PushNotificationsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup { sign_in_as(User.take) }

  test "requires authentication" do
    reset!
    get new_admin_push_notification_path
    assert_redirected_to new_session_path
  end

  test "new renders the form" do
    get new_admin_push_notification_path
    assert_response :success
    assert_select "form input[name=title]"
  end

  test "create enqueues a broadcast" do
    Rails.application.credentials.stub(:dig, "fake_vapid_public_key") do
      assert_enqueued_with(job: BroadcastPushJob, args: [ { title: "Hi", body: "New show added", url: "/shows" } ]) do
        post admin_push_notification_path, params: { title: "Hi", body: "New show added", url: "/shows" }
      end
    end
    assert_redirected_to admin_root_path
  end

  test "create rejects blank fields and bad urls" do
    Rails.application.credentials.stub(:dig, "fake_vapid_public_key") do
      assert_no_enqueued_jobs do
        post admin_push_notification_path, params: { title: "", body: "x", url: "/" }
        assert_response :unprocessable_entity
        post admin_push_notification_path, params: { title: "Hi", body: "x", url: "javascript:alert(1)" }
        assert_response :unprocessable_entity
        post admin_push_notification_path, params: { title: "Hi", body: "x", url: "//evil.com" }
        assert_response :unprocessable_entity
      end
    end
  end

  test "create refuses when VAPID is not configured" do
    Rails.application.credentials.stub(:dig, nil) do
      assert_no_enqueued_jobs do
        post admin_push_notification_path, params: { title: "Hi", body: "x", url: "/" }
      end
    end
    assert_response :unprocessable_entity
  end
end
