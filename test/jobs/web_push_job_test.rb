require "test_helper"

class WebPushJobTest < ActiveJob::TestCase
  def setup
    @subscription = PushSubscription.create!(
      endpoint: "https://push.example.com/job-test",
      p256dh_key: "fake_p256dh",
      auth_key: "fake_auth"
    )
    # web-push 3.1: ResponseError.new(response, host) — host is the push server URI
    @expired_err  = WebPush::ExpiredSubscription.new(OpenStruct.new(code: "410", body: "Gone"), "push.example.com")
    @invalid_err  = WebPush::InvalidSubscription.new(OpenStruct.new(code: "404", body: "Not Found"), "push.example.com")
  end

  test "silently skips a missing subscription id" do
    assert_nothing_raised do
      WebPushJob.new.perform(0, title: "Test", body: "Body")
    end
  end

  test "destroys subscription on ExpiredSubscription (410)" do
    err = @expired_err
    WebPush.stub(:payload_send, ->(*) { raise err }) do
      WebPushJob.new.perform(@subscription.id, title: "Test", body: "Body")
    end
    assert_not PushSubscription.exists?(@subscription.id)
  end

  test "destroys subscription on InvalidSubscription (404)" do
    err = @invalid_err
    WebPush.stub(:payload_send, ->(*) { raise err }) do
      WebPushJob.new.perform(@subscription.id, title: "Test", body: "Body")
    end
    assert_not PushSubscription.exists?(@subscription.id)
  end
end
