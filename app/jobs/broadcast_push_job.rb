class BroadcastPushJob < ApplicationJob
  queue_as :default

  def perform(title:, body:, url: "/")
    return unless Rails.application.credentials.dig(:vapid, :public_key)

    PushSubscription.find_each do |subscription|
      WebPushJob.perform_later(subscription.id, title: title, body: body, url: url)
    end
  end
end
