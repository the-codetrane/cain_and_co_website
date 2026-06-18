class OrderMailer < ApplicationMailer
  def receipt(order)
    @order = order
    mail(
      to: @order.buyer_email,
      subject: "Your Cain & Co. order is confirmed (##{@order.id})"
    )
  end
end
