module Pos
  class ApproveDiscount
    include Support

    def initialize(sale:, actor:, amount_cents:, reason:)
      @sale, @actor, @amount, @reason = sale, actor, amount_cents.to_i, reason.to_s.squish
    end

    def call
      return failure(@sale, "اعتماد الخصم اليدوي متاح للمدير فقط") unless @actor&.can_approve_pos_discounts?
      return failure(@sale, "عملية البيع ليست مسودة") unless @sale.draft?
      return failure(@sale, "قيمة الخصم يجب أن تكون موجبة") unless @amount.positive?
      return failure(@sale, "سبب الخصم مطلوب") if @reason.blank?
      Recalculate.call(@sale)
      maximum = @sale.subtotal_cents - @sale.automatic_discount_cents
      return failure(@sale, "الخصم لا يمكن أن يتجاوز قيمة البيع") if @amount > maximum
      @sale.update!(manual_discount_cents: @amount, manual_discount_reason: @reason,
        discount_approved_by: @actor, discount_approved_at: Time.current,
        total_cents: maximum - @amount)
      audit(@actor, @sale, "pos_discount_approved", amount_cents: @amount)
      success(@sale)
    rescue ActiveRecord::RecordInvalid => error
      failure(@sale, error.record.errors.full_messages)
    end
  end
end
