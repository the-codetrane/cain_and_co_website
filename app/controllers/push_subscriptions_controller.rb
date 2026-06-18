class PushSubscriptionsController < ApplicationController
  def create
    sub = PushSubscription.find_or_initialize_by(endpoint: push_subscription_params[:endpoint])
    sub.update!(push_subscription_params)
    head :created
  rescue ActionController::ParameterMissing
    head :bad_request
  end

  private

  def push_subscription_params
    params.require(:push_subscription).permit(:endpoint, :p256dh_key, :auth_key, :user_agent)
  end
end
