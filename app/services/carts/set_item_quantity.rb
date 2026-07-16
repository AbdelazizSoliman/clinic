module Carts
  class SetItemQuantity
    Result = Data.define(:success?, :item, :message, :notice)

    def initialize(cart:, product:, quantity:, additive: false)
      @cart, @product, @quantity, @additive = cart, product, quantity, additive
    end

    def call
      return failure("المنتج غير متوفر حاليًا") unless @product&.active? && @product.available?

      requested = Integer(@quantity, exception: false)
      return failure("الكمية غير صحيحة") unless requested&.positive?

      item = @cart.items.find_or_initialize_by(product: @product)
      requested += item.quantity.to_i if @additive
      allowed = [ requested, CartItem::MAX_QUANTITY, @product.stock_quantity ].min
      item.quantity = allowed
      item.save!
      notice = @product.requires_prescription? ? "سيطلب الصيدلي مراجعة الروشتة قبل التأكيد" : nil
      Result.new(success?: true, item:, message: requested > allowed ? "تم ضبط الكمية على الحد المتاح (#{allowed})" : "تم تحديث سلة التسوق", notice:)
    rescue ActiveRecord::RecordInvalid
      failure("تعذر تحديث سلة التسوق")
    end

    private

    def failure(message) = Result.new(success?: false, item: nil, message:, notice: nil)
  end
end
