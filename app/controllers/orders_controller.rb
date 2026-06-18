class OrdersController < ApplicationController
  def success
    @order = verified_order
    session.delete(:cart_token)
  end

  def cancel
    @order = verified_order
  end

  private

  def verified_order
    order = Order.find(params[:id])
    raise ActiveRecord::RecordNotFound unless params[:session_id].present? &&
      order.stripe_checkout_session_id == params[:session_id]
    order
  end
end
