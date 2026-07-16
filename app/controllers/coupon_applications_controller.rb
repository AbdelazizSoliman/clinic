class CouponApplicationsController < ApplicationController
  MAX_ATTEMPTS = 8
  WINDOW = 10.minutes

  def create
    return respond_result(false, "تعذر تطبيق الكود حاليًا؛ حاول لاحقًا", :too_many_requests) if throttled?
    result = Promotions::ApplyCoupon.new(cart: resolve_cart!, code: params[:code], user: current_user).call
    record_attempt unless result.success?
    respond_result(result.success?, result.success? ? "تم تطبيق كود الخصم" : "الكود غير صالح أو غير متاح لهذه السلة")
  end

  def destroy
    Promotions::RemoveCoupon.call(resolve_cart!)
    respond_result(true, "تمت إزالة كود الخصم")
  end

  private

  def throttled?
    data = session[:coupon_attempts]
    data && Time.zone.parse(data["started_at"]) > WINDOW.ago && data["count"].to_i >= MAX_ATTEMPTS
  rescue ArgumentError
    false
  end

  def record_attempt
    data = session[:coupon_attempts]
    if data.blank? || Time.zone.parse(data["started_at"]) <= WINDOW.ago
      session[:coupon_attempts] = { "started_at" => Time.current.iso8601, "count" => 1 }
    else
      data["count"] = data["count"].to_i + 1
      session[:coupon_attempts] = data
    end
  rescue ArgumentError
    session[:coupon_attempts] = { "started_at" => Time.current.iso8601, "count" => 1 }
  end

  def respond_result(success, message, status = nil)
    @cart = current_cart&.reload
    flash.now[success ? :notice : :alert] = message
    respond_to do |format|
      format.turbo_stream { render "carts/update", status: status || (success ? :ok : :unprocessable_entity) }
      format.html { redirect_to cart_path, flash: { success ? :notice : :alert => message }, status: :see_other }
    end
  end
end
