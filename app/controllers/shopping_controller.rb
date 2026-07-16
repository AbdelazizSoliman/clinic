class ShoppingController < ApplicationController
  def checkout
    unless user_signed_in?
      store_location_for(:user, checkout_path)
      redirect_to new_user_session_path, notice: "سجّل الدخول أو أنشئ حسابًا للمتابعة إلى الدفع وحفظ عنوان التوصيل"
      return
    end

    @cart = current_cart
    @cart&.ensure_checkout_submission_token!
    @addresses = current_user.addresses.where(active: true).order(default: :desc, created_at: :desc)
    @selected_address = @addresses.find_by(id: params[:address_id]) || @addresses.find_by(default: true) || @addresses.first
    prepare_delivery_options
    @pricing = Checkout::Totals.call(@cart&.valid_items || [], zone: @delivery_zone,
      delivery_method: @delivery_methods.find { |method| method.code == @selected_delivery_method },
      user: current_user, coupon: @cart&.applied_coupon)
    @readiness = Checkout::Readiness.new(user: current_user, cart: @cart, address: @selected_address,
      payment_method: "cash_on_delivery", delivery_method: @selected_delivery_method,
      delivery_slot: @selected_delivery_slot).call
    @cart_issues = cart_issues
    @recommendations = Product.includes(:brand, :category).discounted.available.limit(4)
  end

  private

  def prepare_delivery_options
    @delivery_zone = Delivery::ZoneMatcher.call(@selected_address).zone if @selected_address
    @delivery_methods = @delivery_zone&.delivery_methods&.active&.ordered || DeliveryMethod.none
    @selected_delivery_method = params[:delivery_method].presence_in(@delivery_methods.map(&:code)) || @delivery_methods.first&.code || "standard"
    @delivery_slots = @delivery_zone&.delivery_slots&.available&.order(:delivery_date, :starts_at) || DeliverySlot.none
    @selected_delivery_slot = @delivery_slots.find_by(id: params[:delivery_slot_id])
  end

  def cart_issues
    return [] unless @cart

    @cart.items.includes(:product).filter_map do |item|
      if !item.product.active? || !item.product.available?
        "#{item.product.name} لم يعد متاحًا؛ عدّل السلة قبل المتابعة"
      elsif item.quantity > item.product.available_to_sell_quantity
        "كمية #{item.product.name} تتجاوز المتاح للبيع حاليًا (#{item.product.available_to_sell_quantity})"
      end
    end
  end
end
