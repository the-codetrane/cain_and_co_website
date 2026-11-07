module Admin
  class ProductsController < BaseController
    before_action :set_product, only: %i[show edit update destroy]

    def index
      @products = Product.includes(:variants).by_name
    end

    def show
    end

    def new
      @product = Product.new
    end

    def create
      @product = Product.new(product_params)
      if @product.save
        redirect_to admin_product_path(@product), notice: "Product created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @product.update(product_params)
        redirect_to admin_product_path(@product), notice: "Product updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @product.destroy
      redirect_to admin_products_path, notice: "Product deleted.", status: :see_other
    end

    private

    def set_product
      @product = Product.find(params[:id])
    end

    def product_params
      permitted = params.require(:product).permit(:name, :description, :published, :featured, images: []).to_h

      # The file field submits a blank entry when nothing is chosen, and assigning
      # only blanks would detach every image, so leave them out unless files came in.
      uploads = Array(permitted.delete(:images)).compact_blank
      permitted[:images] = uploads.map { |upload| Product.image_attachable(upload) } if uploads.any?
      permitted
    end
  end
end
