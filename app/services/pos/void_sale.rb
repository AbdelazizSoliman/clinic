module Pos
  class VoidSale
    include Support

    def initialize(sale:, actor:, reason:)
      @sale, @actor, @reason = sale, actor, reason.to_s.squish
    end

    def call
      return failure(@sale, "غير مصرح") unless @actor&.can_operate_pos? && (@sale.cashier_id == @actor.id || @actor.admin?)
      return success(@sale) if @sale.voided?
      return failure(@sale, "لا يمكن إلغاء عملية بيع مكتملة") unless @sale.draft?
      return failure(@sale, "سبب الإلغاء مطلوب") if @reason.blank?
      @sale.update!(status: :voided, voided_at: Time.current, voided_by: @actor, void_reason: @reason)
      audit(@actor, @sale, "pos_sale_voided", reason: @reason)
      success(@sale)
    rescue ActiveRecord::RecordInvalid => error
      failure(@sale, error.record.errors.full_messages)
    end
  end
end
