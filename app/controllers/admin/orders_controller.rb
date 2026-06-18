module Admin
  class OrdersController < BaseController
    before_action :set_order, only: %i[show fulfill]

    def index
      @needs_fulfillment = Order.needs_fulfillment.includes(:order_items)
      @recent = Order.recent.limit(50).includes(:order_items)
    end

    def show
    end

    def fulfill
      if @order.paid?
        @order.update!(status: "fulfilled")
        redirect_to admin_order_path(@order), notice: "Order marked as fulfilled."
      else
        redirect_to admin_order_path(@order), alert: "Only paid orders can be fulfilled."
      end
    end

    private

    def set_order
      @order = Order.includes(order_items: :variant).find(params[:id])
    end
  end
end
