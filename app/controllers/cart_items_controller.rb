class CartItemsController < ApplicationController
  before_action :set_variant, only: :create

  def create
    cart = find_or_create_cart
    quantity = (params[:quantity] || 1).to_i.clamp(1, 99)
    cart.add_variant(@variant, quantity: quantity)
    redirect_to cart_path, notice: "Added to cart."
  rescue ActiveRecord::RecordInvalid
    redirect_to product_path(@variant.product), alert: "Could not add to cart."
  end

  def update
    item = current_cart&.cart_items&.find_by(id: params[:id])
    if item
      qty = params[:quantity].to_i
      if qty <= 0
        item.destroy
        redirect_to cart_path, notice: "Item removed."
      else
        item.update!(quantity: qty.clamp(1, 99))
        redirect_to cart_path
      end
    else
      redirect_to cart_path
    end
  end

  def destroy
    item = current_cart&.cart_items&.find_by(id: params[:id])
    item&.destroy
    redirect_to cart_path, notice: "Item removed.", status: :see_other
  end

  private

  def set_variant
    @variant = Variant.joins(:product).merge(Product.published).find(params[:variant_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to products_path, alert: "Item not available." and return
  end

  def find_or_create_cart
    token = session[:cart_token]
    cart = token && Cart.find_by(token: token)
    unless cart
      cart = Cart.create!
      session[:cart_token] = cart.token
    end
    cart
  end

  def current_cart
    token = session[:cart_token]
    token && Cart.find_by(token: token)
  end
end
