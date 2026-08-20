module Pos
  class Cart
    include Support

    def initialize(sale:, actor:)
      @sale, @actor = sale, actor
    end

    def add(product:, quantity: 1)
      return failure(@sale, "غير مصرح بتشغيل نقطة البيع") unless authorized?
      return failure(@sale, "عملية البيع ليست مسودة") unless @sale.draft?
      return failure(@sale, "لم يتم العثور على منتج بهذا الباركود أو المعرّف") unless product
      return failure(@sale, "المنتج غير نشط") unless product.active?
      quantity = quantity.to_i
      return failure(@sale, "الكمية يجب أن تكون موجبة") unless quantity.positive?

      PosSale.transaction do
        @sale.lock!
        product.lock!
        item = @sale.items.find_or_initialize_by(product:)
        requested = (item.quantity || 0) + quantity
        return failure(@sale, "الكمية المتاحة غير كافية") if requested > product.available_to_sell_quantity
        cents = (product.price * 100).round
        item.assign_attributes(product_name: product.name, product_sku: product.sku, product_barcode: product.barcode,
          quantity: requested, original_unit_price_cents: cents, unit_price_cents: cents,
          discount_cents: 0, line_total_cents: cents * requested,
          requires_prescription: product.requires_prescription?)
        item.save!
        sync_review_item(item)
        Recalculate.call(@sale)
      end
      success(@sale)
    rescue ActiveRecord::RecordInvalid => error
      failure(@sale, error.record.errors.full_messages)
    end

    def update(item:, quantity:)
      return failure(@sale, "غير مصرح") unless authorized? && item.pos_sale_id == @sale.id && @sale.draft?
      return failure(@sale, "لا يمكن تعديل بند بعد القرار السريري") if item.prescription_review_item&.terminal?
      quantity = quantity.to_i
      return remove(item:) unless quantity.positive?
      return failure(@sale, "الكمية المتاحة غير كافية") if quantity > item.product.available_to_sell_quantity
      PosSale.transaction do
        item.update!(quantity:)
        sync_review_item(item)
        Recalculate.call(@sale)
      end
      success(@sale)
    rescue ActiveRecord::RecordInvalid => error
      failure(@sale, error.record.errors.full_messages)
    end

    def remove(item:)
      return failure(@sale, "غير مصرح") unless authorized? && item.pos_sale_id == @sale.id && @sale.draft?
      return failure(@sale, "لا يمكن حذف بند بعد القرار السريري") if item.prescription_review_item&.terminal?
      PosSale.transaction { item.destroy!; Recalculate.call(@sale); reevaluate_safety }
      success(@sale)
    end

    private

    def sync_review_item(item)
      return unless item.requires_prescription?
      review = Prescriptions::EnsureReview.call(@sale, actor: @actor)
      review_item = review.items.find_by!(reviewable_item: item)
      review_item.update!(quantity: item.quantity) unless review_item.quantity == item.quantity
      DrugSafety::Reevaluate.call(review, trigger: :cart_changed, actor: @actor)
    end

    def reevaluate_safety
      review = @sale.prescription_review
      DrugSafety::Reevaluate.call(review.reload, trigger: :cart_changed, actor: @actor) if review
    end

    def authorized? = @actor&.can_operate_pos? && (@sale.cashier_id == @actor.id || @actor.admin?)
  end
end
