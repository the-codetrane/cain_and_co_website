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

    # Bulk-adds a whole size run in one submit (the "size buttons" picker on the
    # product page). Sizes already defined on the product are skipped rather than
    # rejected, so re-submitting the picker is safe.
    def add_sizes
      sizes = Array(params[:sizes]).map(&:to_s).uniq.select { |s| Variant::SIZES.include?(s) }
      if sizes.empty?
        redirect_to admin_product_path(@product), alert: "Pick at least one size." and return
      end

      price_cents    = params[:price_cents].to_i
      stock_quantity = params[:stock_quantity].to_i
      existing       = @product.existing_size_names

      created = []
      Variant.transaction do
        (sizes - existing).each do |size|
          created << @product.variants.create!(
            name: size, price_cents: price_cents, stock_quantity: stock_quantity
          )
        end
      end

      skipped = sizes.size - created.size
      notice  = "Added #{helpers.pluralize(created.size, 'size')}."
      notice += " #{skipped} already existed." if skipped.positive?
      redirect_to admin_product_path(@product), notice: notice
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_product_path(@product), alert: "Could not add sizes: #{e.record.errors.full_messages.to_sentence}"
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
      params.require(:variant).permit(:name, :price_cents, :stock_quantity, :sku, :position)
    end
  end
end
