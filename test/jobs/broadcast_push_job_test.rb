require "test_helper"

class BroadcastPushJobTest < ActiveJob::TestCase
  def setup
    PushSubscription.delete_all
  end

  test "enqueues one WebPushJob per subscription when VAPID is configured" do
    PushSubscription.create!(endpoint: "https://a.example.com", p256dh_key: "k1", auth_key: "a1")
    PushSubscription.create!(endpoint: "https://b.example.com", p256dh_key: "k2", auth_key: "a2")

    Rails.application.credentials.stub(:dig, "fake_vapid_public_key") do
      assert_enqueued_jobs 2, only: WebPushJob do
        BroadcastPushJob.new.perform(title: "Test", body: "Body")
      end
    end
  end

  test "is a no-op when VAPID key is not configured" do
    PushSubscription.create!(endpoint: "https://a.example.com", p256dh_key: "k", auth_key: "a")

    Rails.application.credentials.stub(:dig, nil) do
      assert_enqueued_jobs 0 do
        BroadcastPushJob.new.perform(title: "Test", body: "Body")
      end
    end
  end
end
