require "test_helper"

class Admin::SubscribersControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:one)) }

  test "index requires authentication" do
    reset!
    get admin_subscribers_path
    assert_redirected_to new_session_path
  end

  test "index shows counts and list" do
    get admin_subscribers_path
    assert_response :success
    assert_match subscribers(:confirmed_fan).email, response.body
  end

  test "index search filters by email" do
    get admin_subscribers_path(q: "confirmed@")
    assert_response :success
    assert_match subscribers(:confirmed_fan).email, response.body
    assert_no_match subscribers(:unconfirmed_fan).email, response.body
  end

  test "csv export returns text/csv with rows" do
    get admin_subscribers_path(format: :csv)
    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_match "email,status,confirmed_at", response.body
    assert_match subscribers(:confirmed_fan).email, response.body
  end

  test "admin-added subscriber is confirmed immediately" do
    assert_difference -> { Subscriber.count }, 1 do
      post admin_subscribers_path, params: { subscriber: { email: "vip@fan.com" } }
    end
    assert_equal "confirmed", Subscriber.find_by(email: "vip@fan.com").status
    assert_redirected_to admin_subscribers_path
  end

  test "resend confirmation enqueues email for unconfirmed" do
    assert_enqueued_emails 1 do
      post resend_confirmation_admin_subscriber_path(subscribers(:unconfirmed_fan))
    end
  end

  test "resend confirmation no-ops for confirmed" do
    assert_no_enqueued_emails do
      post resend_confirmation_admin_subscriber_path(subscribers(:confirmed_fan))
    end
  end

  test "destroy removes a subscriber" do
    assert_difference -> { Subscriber.count }, -1 do
      delete admin_subscriber_path(subscribers(:unsubscribed_fan))
    end
  end

  # CSV import
  test "import shows the upload form" do
    get import_admin_subscribers_path
    assert_response :success
    assert_match "Import subscribers", response.body
  end

  test "import creates new confirmed subscribers from csv" do
    csv = fixture_file_upload("subscribers_import.csv", "text/csv")
    assert_difference -> { Subscriber.count }, 2 do
      post import_admin_subscribers_path, params: { csv_file: csv }
    end
    assert_redirected_to admin_subscribers_path
    assert_match "Imported 2 subscribers", flash[:notice]
  end

  test "import skips already-existing emails" do
    csv = fixture_file_upload("subscribers_import.csv", "text/csv")
    post import_admin_subscribers_path, params: { csv_file: csv }
    assert_match "1 already existed", flash[:notice]
  end

  test "import reports invalid rows" do
    csv = fixture_file_upload("subscribers_import.csv", "text/csv")
    post import_admin_subscribers_path, params: { csv_file: csv }
    assert_match "2 invalid", flash[:notice]
  end

  test "imported subscribers are confirmed immediately" do
    csv = fixture_file_upload("subscribers_import.csv", "text/csv")
    post import_admin_subscribers_path, params: { csv_file: csv }
    assert Subscriber.find_by(email: "import1@example.com").confirmed?
  end

  test "import without a file re-renders form with error" do
    post import_admin_subscribers_path, params: {}
    assert_response :unprocessable_entity
    assert_match "Please choose a CSV file", response.body
  end

  test "import with no email column re-renders form with format guidance" do
    csv = fixture_file_upload("subscribers_import_no_email_col.csv", "text/csv")
    post import_admin_subscribers_path, params: { csv_file: csv }
    assert_response :unprocessable_entity
    assert_match "No email column found", response.body
    assert_match "Email", response.body
  end
end
