module Checkout
  class Readiness
    Result = Data.define(:ready, :errors, :prescription_required)

    def initialize(user:, cart:, address:, payment_method: "cash_on_delivery", delivery_method: "standard", delivery_slot: nil)
      @user = user
      @cart = cart
      @address = address
      @payment_method = payment_method
      @delivery_method = delivery_method
      @delivery_slot = delivery_slot
    end

    def call
      errors = []
      errors << "يجب تسجيل الدخول" unless @user
      errors << "السلة فارغة" if @cart.blank? || @cart.items.empty?
      if @cart
        errors << "تحتوي السلة على منتجات غير متاحة" if @cart.items.includes(:product).any? { |item| !item.product.active? || !item.product.available? }
        errors << "توجد كمية أكبر من المخزون المتاح للبيع" if @cart.items.includes(:product).any? { |item| item.quantity > item.product.available_to_sell_quantity }
      end
      errors << "اختر عنوان توصيل نشطًا من حسابك" unless owned_active_address?
      match = Delivery::ZoneMatcher.call(@address) if owned_active_address?
      errors << (match&.error || "العنوان خارج نطاق التوصيل الحالي") if owned_active_address? && !match&.matched?
      method = match&.zone&.delivery_methods&.active&.find_by(code: @delivery_method)
      errors << "طريقة التوصيل غير متاحة في هذه المنطقة" if match&.matched? && method.nil?
      errors << "اختر موعد توصيل متاحًا" if @delivery_method == "scheduled" && (!@delivery_slot&.available? || @delivery_slot.delivery_zone_id != match&.zone&.id)
      errors << "الطلب أقل من الحد الأدنى للمنطقة" if match&.zone&.minimum_order_cents && @cart && @cart.subtotal_cents < match.zone.minimum_order_cents
      errors << "الدفع عند الاستلام هو الطريقة المتاحة حاليًا" unless @payment_method == "cash_on_delivery"
      Result.new(ready: errors.empty?, errors:, prescription_required: @cart&.requires_prescription? || false)
    end

    private

    def owned_active_address?
      @user && @address&.active? && @address.user_id == @user.id
    end
  end
end
