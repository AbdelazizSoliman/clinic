module Admin
  class CouponsController < BaseController
    before_action :authorize_promotions!
    before_action :set_promotion
    before_action :set_coupon, only: %i[edit update destroy]
    def new = @coupon = @promotion.coupons.new
    def create
      @coupon = @promotion.coupons.new(coupon_params)
      if @coupon.save
        redirect_to admin_promotion_path(@promotion), notice: "تم إنشاء الكوبون"
      else
        render :new, status: :unprocessable_entity
      end
    end
    def edit; end
    def update
      if @coupon.update(coupon_params)
        redirect_to admin_promotion_path(@promotion), notice: "تم تحديث الكوبون"
      else
        render :edit, status: :unprocessable_entity
      end
    end
    def destroy
      return redirect_to(admin_promotion_path(@promotion), alert: "أوقف الكوبون المستخدم بدل حذفه") if @coupon.redemptions.exists?
      @coupon.destroy!
      redirect_to admin_promotion_path(@promotion), notice: "تم حذف الكوبون"
    end
    private
    def authorize_promotions!
      head(:not_found) unless current_user.can_manage_promotions?
    end
    def set_promotion = @promotion = Promotion.find(params[:promotion_id])
    def set_coupon = @coupon = @promotion.coupons.find(params[:id])
    def coupon_params = params.require(:coupon).permit(:code, :active, :starts_at, :ends_at, :total_usage_limit,
      :per_customer_usage_limit, :minimum_subtotal_cents, :maximum_discount_cents, :first_order_only, :authenticated_only, :lock_version)
  end
end
