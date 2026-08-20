module Admin
  # Links a catalogue product to a stable clinical identity. Rules never match on product names.
  class ProductActiveIngredientsController < BaseController
    before_action :set_product

    def create
      link = @product.product_active_ingredients.find_or_initialize_by(active_ingredient_id: params[:active_ingredient_id])
      link.assign_attributes(strength: params[:strength], unit: params[:unit], active: true)
      if link.save
        AdminAuditEvent.create!(actor: current_user, auditable: @product, action: "product_ingredient_linked",
          metadata: { active_ingredient_id: link.active_ingredient_id, strength: link.strength })
        redirect_to admin_product_path(@product), notice: "تم ربط المادة الفعالة بالمنتج"
      else
        redirect_to admin_product_path(@product), alert: link.errors.full_messages.join("، ")
      end
    end

    def destroy
      link = @product.product_active_ingredients.find(params[:id])
      link.destroy!
      AdminAuditEvent.create!(actor: current_user, auditable: @product, action: "product_ingredient_unlinked",
        metadata: { active_ingredient_id: link.active_ingredient_id })
      redirect_to admin_product_path(@product), notice: "تم فك ارتباط المادة الفعالة"
    end

    private

    def set_product = @product = Product.find_by!(slug: params[:product_id])
  end
end
