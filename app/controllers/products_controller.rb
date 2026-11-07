class ProductsController < ApplicationController
  def index
    @products = Product.published.includes(:variants).with_image_variants.by_name
    @grid_cache_key = grid_cache_key
  end

  def show
    @product = Product.published.includes(:variants).with_image_variants.find(params[:id])
  end

  private

  # The cards show stock, which changes on every sale. `Variant.all` covers that without
  # `touch: true`, which Variant#adjust_stock's update_all would skip. The newest variant
  # record is there so a card cached before its image was generated picks up the CDN URL.
  def grid_cache_key
    [ @products, Variant.all, ActiveStorage::VariantRecord.maximum(:id) ]
  end
end
