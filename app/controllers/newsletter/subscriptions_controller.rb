# Account-free newsletter signup with double opt-in. Public by default
# (see ApplicationController). Namespaced under the Newsletter model, which
# doubles as the namespace for its public-facing controllers.
class Newsletter::SubscriptionsController < ApplicationController
  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to root_path(anchor: "newsletter"), alert: "Please try again in a moment." }

  def create
    email = params.dig(:subscriber, :email)
    subscriber = Subscriber.find_or_initialize_by(email: Subscriber.new(email: email).email)

    if subscriber.persisted? && subscriber.confirmed?
      # Already on the list — don't leak status differences, just say thanks.
      return redirect_to root_path(anchor: "newsletter"), notice: thanks_message
    end

    # Reactivate a previously-unsubscribed address by clearing the flag before re-opting-in.
    subscriber.unsubscribed_at = nil

    if subscriber.save
      SubscriberMailer.with(subscriber: subscriber).confirmation.deliver_later
      redirect_to root_path(anchor: "newsletter"), notice: thanks_message
    else
      redirect_to root_path(anchor: "newsletter"),
                  alert: subscriber.errors.full_messages.to_sentence.presence || "Please enter a valid email address."
    end
  end

  def confirm
    subscriber = Subscriber.find_by_token_for(:confirmation, params[:token])
    if subscriber
      subscriber.confirm!
      render :confirmed
    else
      render :invalid_token, status: :unprocessable_entity
    end
  end

  private

  def thanks_message
    "Almost there — check your inbox for a confirmation link."
  end
end
