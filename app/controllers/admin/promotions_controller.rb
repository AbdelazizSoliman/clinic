module Admin
  class PromotionsController < BaseController
    before_action :authorize_promotions!
    before_action :set_promotion, only: %i[show edit update destroy activate pause]
    def index
      scope = Promotion.includes(:coupons, :redemptions)
      @pagy, @promotions = pagy(Admin::PromotionsQuery.new(scope, params.permit(:type, :active, :automatic, :sort)).call, limit: 20)
    end
    def show; end
    def new = @promotion = Promotion.new(starts_at: Time.current, ends_at: 1.month.from_now, active: false)
    def edit; end
    def create
      @promotion = Promotion.new(promotion_params.merge(created_by: current_user, updated_by: current_user))
      if @promotion.save
        sync_targets
        audit("create")
        redirect_to admin_promotion_path(@promotion), notice: "تم إنشاء الحملة"
      else
        render :new, status: :unprocessable_entity
      end
    end
    def update
      before = @promotion.attributes.slice(*promotion_params.keys)
      if @promotion.update(promotion_params.merge(updated_by: current_user))
        sync_targets
        audit("update", before:)
        redirect_to admin_promotion_path(@promotion), notice: "تم تحديث الحملة"
      else
        render :edit, status: :unprocessable_entity
      end
    rescue ActiveRecord::StaleObjectError
      redirect_to edit_admin_promotion_path(@promotion), alert: "عُدلت الحملة بواسطة مستخدم آخر"
    end
    def activate = set_active(true, "تم تفعيل الحملة")
    def pause = set_active(false, "تم إيقاف الحملة")
    def destroy
      return redirect_to(admin_promotion_path(@promotion), alert: "لا يمكن حذف حملة مستخدمة") if @promotion.redemptions.exists?
      @promotion.destroy!
      redirect_to admin_promotions_path, notice: "تم حذف الحملة"
    end
    private
    def authorize_promotions!
      head(:not_found) unless current_user.can_manage_promotions?
    end
    def set_promotion = @promotion = Promotion.find(params[:id])
    def promotion_params
      params.require(:promotion).permit(:name, :internal_name, :description, :promotion_type, :discount_type,
        :discount_value, :maximum_discount_cents, :minimum_subtotal_cents, :starts_at, :ends_at, :active,
        :priority, :stackable, :automatic, :first_order_only, :authenticated_only, :total_usage_limit,
        :per_customer_usage_limit, :applies_to_prescription_products, :delivery_zone_id, :delivery_method_code, :lock_version)
    end
    def sync_targets
      { product_ids: @promotion.product_ids, category_ids: @promotion.category_ids, brand_ids: @promotion.brand_ids,
        excluded_product_ids: @promotion.excluded_product_ids }.each_key do |key|
        @promotion.public_send("#{key}=", Array(params.dig(:promotion, key)).compact_blank)
      end
    end
    def audit(action, changes = {})
      @promotion.promotion_audit_events.create!(actor: current_user, action:, changes:)
    end
    def set_active(value, message)
      @promotion.update!(active: value, updated_by: current_user)
      audit(value ? "activate" : "pause")
      redirect_to admin_promotion_path(@promotion), notice: message
    end
  end
end
