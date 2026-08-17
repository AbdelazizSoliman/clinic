module Pos
  class ApprovePrescription
    include Support

    def initialize(item:, actor:, reason:)
      @item, @actor, @reason = item, actor, reason.to_s.squish
    end

    def call
      return failure(@item, "اعتماد أدوية الروشتة متاح للصيدلي فقط") unless @actor&.can_approve_pos_prescriptions?
      return failure(@item, "عملية البيع ليست مسودة") unless @item.pos_sale.draft?
      return success(@item) unless @item.requires_prescription?
      review = Prescriptions::EnsureReview.call(@item.pos_sale)
      review_item = review.items.find_by!(reviewable_item: @item)
      result = Prescriptions::DecideLine.new(item: review_item, actor: @actor,
        decision: :approved, reason: @reason).call
      if result.success?
        @item.update!(prescription_approved_by: @actor, prescription_approved_at: result.item.reviewed_at,
          prescription_approval_reason: @reason)
        success(@item)
      else
        failure(@item, result.errors)
      end
    end
  end
end
