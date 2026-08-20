module Returns
  class ConfirmRefund
    include Support
    def initialize(refund:, actor:, external_reference:)
      @refund, @actor, @reference = refund, actor, external_reference.to_s.squish
    end
    def call
      return failure(@refund, "تأكيد الاسترداد متاح للمدير فقط") unless @actor&.can_refund_returns?
      return success(@refund) if @refund.completed?
      @refund.with_lock do
        raise ActiveRecord::RecordInvalid, @refund unless @refund.pending? && @refund.external_card? && @reference.present?
        @refund.update!(status: :completed, refunded_at: Time.current, external_reference: @reference)
        audit(@actor, @refund.return_request, "refund_completed", refund_id: @refund.id)
        request = @refund.return_request
        request.update!(status: :refunded) if request.refunds.completed.sum(:amount_cents) == request.refundable_cents
      end
      success(@refund)
    rescue ActiveRecord::RecordInvalid => error
      failure(@refund, error.record.errors.full_messages)
    end
  end
end
