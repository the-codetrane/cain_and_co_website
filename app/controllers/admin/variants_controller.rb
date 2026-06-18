module Admin
  class VariantsController < BaseController
    before_action :set_product
    before_action :set_variant, only: %i[edit update destroy]

    def new
      @variant = @product.variants.new
    end

    def create
      @variant = @product.variants.new(variant_params)
      if @variant.save
        redirect_to admin_product_path(@product), notice: "Variant added."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @variant.update(variant_params)
        redirect_to admin_product_path(@product), notice: "Variant updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @variant.destroy
      redirect_to admin_product_path(@product), notice: "Variant deleted.", status: :see_other
    end

    private

    def set_product
      @product = Product.find(params[:product_id])
    end

    def set_variant
      @variant = @product.variants.find(params[:id])
    end

    def variant_params
      params.require(:variant).permit(:name, :price_cents, :stock_quantity, :sku)
    end
  end
end
