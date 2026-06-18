class ProductsController < ApplicationController
  def index
    @products = Product.published.includes(:variants, images_attachments: :blob).by_name
  end

  def show
    @product = Product.published.includes(:variants, images_attachments: :blob).find(params[:id])
  end
end
