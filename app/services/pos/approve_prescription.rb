module Pos
  class ApprovePrescription
    include Support

    def initialize(item:, actor:, reason:)
      @item, @actor, @reason = item, actor, reason.to_s.squish
    end

    def call
      return failure(@item, "اعتماد أدوية الروشتة متاح للصيدلي فقط") unless @actor&.can_approve_pos_prescriptions?
      return failure(@item, "عملية البيع ليست مسودة") unless @item.pos_sale.draft?
      return failure(@item, "سبب الاعتماد مطلوب") if @reason.blank?
      return success(@item) unless @item.requires_prescription?

      @item.update!(prescription_approved_by: @actor, prescription_approved_at: Time.current,
        prescription_approval_reason: @reason)
      audit(@actor, @item.pos_sale, "pos_prescription_approved", item_id: @item.id, product_id: @item.product_id)
      success(@item)
    rescue ActiveRecord::RecordInvalid => error
      failure(@item, error.record.errors.full_messages)
    end
  end
end
