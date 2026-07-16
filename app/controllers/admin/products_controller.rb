module Admin
  class ProductsController < BaseController
    before_action :set_product, only: %i[show edit update destroy deactivate update_pricing]

    def index
      scope = Product.includes(:category, :brand, :images, :inventory_reservations)
      @pagy, @products = pagy(Admin::ProductsQuery.new(scope, params.permit(:q, :category_id, :brand_id, :active, :featured, :prescription, :discounted, :out_of_stock, :low_stock, :cold_chain, :sort)).call, limit: 20)
    end
    def show; end
    def new = @product = Product.new(active: false, price: 0, stock_quantity: 0, published_at: nil)
    def edit; end
    def create
      @product = Product.new(product_params.merge(price: 0, stock_quantity: 0))
      if @product.save
        audit(@product, "product_created", @product.saved_changes.except("updated_at"))
        redirect_to admin_product_path(@product), notice: "تم إنشاء المنتج كمسودة"
      else
        render :new, status: :unprocessable_entity
      end
    end
    def update
      if @product.update(product_params)
        audit(@product, "product_updated", @product.saved_changes.except("updated_at"))
        redirect_to admin_product_path(@product), notice: "تم تحديث المنتج"
      else
        render :edit, status: :unprocessable_entity
      end
    rescue ActiveRecord::StaleObjectError
      redirect_to edit_admin_product_path(@product), alert: "تم تحديث المنتج بواسطة مستخدم آخر"
    end
    def deactivate
      @product.update!(active: false, discontinued_at: Time.current)
      audit(@product, "product_deactivated", { active: [ true, false ] })
      redirect_to admin_products_path, notice: "تم إيقاف المنتج"
    end
    def destroy
      return redirect_to(admin_product_path(@product), alert: "لا يمكن حذف منتج مرتبط بسلة أو طلب أو حجز") unless @product.deletable?
      @product.destroy!
      redirect_to admin_products_path, notice: "تم حذف المنتج"
    end
    def update_pricing
      result = Products::UpdatePricing.new(product: @product, actor: current_user, price: params[:price],
        compare_at_price: params[:compare_at_price], cost_price: params[:cost_price], reason: params[:reason], lock_version: params[:lock_version]).call
      redirect_to admin_product_path(@product), status: :see_other, flash: { result.success? ? :notice : :alert => result.success? ? "تم تحديث السعر وتسجيله" : result.errors.join("، ") }
    end

    private
    def set_product = @product = Product.includes(:category, :brand, images: { file_attachment: :blob }).find_by!(slug: params[:id])
    def product_params
      params.require(:product).permit(:name, :slug, :category_id, :brand_id, :short_description, :description,
        :active_ingredient, :dosage_form, :strength, :manufacturer, :sku, :barcode, :low_stock_threshold,
        :maximum_order_quantity, :requires_prescription, :pharmacist_review_required, :cold_chain_required,
        :featured, :active, :published_at, :lock_version)
    end
    def audit(subject, action, changes)
      allowed = %w[name slug category_id brand_id short_description description active_ingredient dosage_form strength manufacturer sku barcode low_stock_threshold maximum_order_quantity requires_prescription pharmacist_review_required cold_chain_required featured active published_at discontinued_at]
      AdminAuditEvent.create!(actor: current_user, auditable: subject, action:, change_data: changes.slice(*allowed))
    end
  end
end
