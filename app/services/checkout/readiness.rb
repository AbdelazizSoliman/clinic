module Checkout
  class Readiness
    Result = Data.define(:ready, :errors, :prescription_required)

    def initialize(user:, cart:, address:, payment_method: "cash_on_delivery")
      @user = user
      @cart = cart
      @address = address
      @payment_method = payment_method
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
      errors << "العنوان خارج نطاق التوصيل التجريبي الحالي" if owned_active_address? && !DeliveryAreaPolicy.supported?(@address)
      errors << "الدفع عند الاستلام هو الطريقة المتاحة حاليًا" unless @payment_method == "cash_on_delivery"
      Result.new(ready: errors.empty?, errors:, prescription_required: @cart&.requires_prescription? || false)
    end

    private

    def owned_active_address?
      @user && @address&.active? && @address.user_id == @user.id
    end
  end
end
