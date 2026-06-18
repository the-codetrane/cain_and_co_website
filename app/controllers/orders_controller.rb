class OrdersController < ApplicationController
  def success
    @order = Order.find(params[:id])
    session.delete(:cart_token)
  end

  def cancel
    @order = Order.find(params[:id])
  end
end
