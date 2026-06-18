class CartsController < ApplicationController
  def show
    @cart = current_cart
  end

  private

  def current_cart
    Cart.includes(cart_items: { variant: :product }).find_by(token: session[:cart_token]) ||
      Cart.new
  end
end
