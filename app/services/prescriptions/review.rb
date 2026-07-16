module Prescriptions
  class Review
    Result = Data.define(:success?, :prescription, :errors)
    FINAL = %w[approved partially_approved rejected].freeze

    def initialize(prescription:, actor:, decision:, customer_message: nil, internal_notes: nil, lock_version: nil)
      @prescription, @actor, @decision = prescription, actor, decision
      @customer_message, @internal_notes, @lock_version = customer_message, internal_notes, lock_version
    end

    def call
      return failure("غير مصرح بمراجعة الروشتة") unless @actor&.can_review_prescriptions?
      return failure("قرار الروشتة غير صحيح") unless %w[under_review approved partially_approved rejected].include?(@decision)
      return failure("سبب الرفض مطلوب") if @decision == "rejected" && @customer_message.blank?
      return failure("رسالة المتابعة مطلوبة") if @decision == "partially_approved" && @customer_message.blank?

      Prescription.transaction do
        @prescription.lock!
        raise ActiveRecord::StaleObjectError.new(@prescription, "review") if @lock_version && @prescription.lock_version != @lock_version.to_i
        allowed = @prescription.submitted? || @prescription.under_review?
        return failure("تم اتخاذ قرار نهائي بالفعل") unless allowed

        from = @prescription.status
        if @decision == "under_review"
          @prescription.update!(status: :under_review, internal_notes: @internal_notes)
          event("prescription_review_started", from, "under_review", false)
        else
          @prescription.update!(status: @decision, reviewed_by: @actor, reviewed_at: Time.current,
            rejection_reason: @decision == "rejected" ? @customer_message : nil,
            customer_message: @customer_message, internal_notes: @internal_notes)
          apply_order_decision(from)
        end
      end
      Result.new(success?: true, prescription: @prescription, errors: [])
    rescue ActiveRecord::StaleObjectError
      failure("تم تحديث الروشتة بواسطة مستخدم آخر؛ أعد تحميل الصفحة")
    rescue ActiveRecord::RecordInvalid => error
      failure(error.record.errors.full_messages.join("، "))
    end

    private

    def apply_order_decision(from)
      case @decision
      when "approved"
        @prescription.order.update!(status: :submitted)
        event("prescription_approved", from, "approved", true)
      when "partially_approved"
        event("prescription_partially_approved", from, "partially_approved", true)
      when "rejected"
        @prescription.order.update!(status: :rejected)
        Inventory::ReleaseReservations.new(@prescription.order).call
        event("prescription_rejected", from, "rejected", true)
        @prescription.order.events.create!(actor: @actor, event_type: "reservations_released", customer_visible: true)
      end
    end

    def event(type, from, to, visible)
      @prescription.order.events.create!(actor: @actor, event_type: type, from_status: from, to_status: to, customer_visible: visible)
    end

    def failure(message) = Result.new(success?: false, prescription: @prescription, errors: [ message ])
  end
end
