class ShoppingController < ApplicationController
  def checkout
    unless user_signed_in?
      store_location_for(:user, checkout_path)
      redirect_to new_user_session_path, notice: "سجّل الدخول أو أنشئ حسابًا للمتابعة إلى الدفع وحفظ عنوان التوصيل"
      return
    end

    @cart = current_cart
    @addresses = current_user.addresses.where(active: true).order(default: :desc, created_at: :desc)
    @selected_address = @addresses.find_by(id: params[:address_id]) || @addresses.find_by(default: true) || @addresses.first
    @readiness = Checkout::Readiness.new(user: current_user, cart: @cart, address: @selected_address, payment_method: params[:payment_method].presence || "cash").call
    @cart_issues = cart_issues
    @recommendations = Product.includes(:brand, :category).discounted.available.limit(4)
  end

  private

  def cart_issues
    return [] unless @cart

    @cart.items.includes(:product).filter_map do |item|
      if !item.product.active? || !item.product.available?
        "#{item.product.name} لم يعد متاحًا؛ عدّل السلة قبل المتابعة"
      elsif item.quantity > item.product.stock_quantity
        "كمية #{item.product.name} تتجاوز المخزون الحالي (#{item.product.stock_quantity})"
      end
    end
  end
end
