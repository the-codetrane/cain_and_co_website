class WebPushJob < ApplicationJob
  queue_as :default

  def perform(subscription_id, title:, body:, url: "/")
    subscription = PushSubscription.find_by(id: subscription_id)
    return unless subscription

    payload = {
      title: title,
      options: { body: body, data: { url: url }, icon: "/icon.png" }
    }.to_json

    WebPush.payload_send(
      message: payload,
      endpoint: subscription.endpoint,
      p256dh: subscription.p256dh_key,
      auth: subscription.auth_key,
      vapid: {
        public_key: Rails.application.credentials.dig(:vapid, :public_key),
        private_key: Rails.application.credentials.dig(:vapid, :private_key),
        subject: "mailto:hello@cainandco.com"
      },
      ttl: 86_400
    )
  rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription
    subscription&.destroy
  end
end
