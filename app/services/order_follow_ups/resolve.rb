module OrderFollowUps
  class Resolve
    Result = Data.define(:success?, :follow_up, :errors)

    def initialize(follow_up:, actor:, message: nil, internal: false, lock_version: nil)
      @follow_up, @actor, @message, @internal, @lock_version = follow_up, actor, message, internal, lock_version
    end

    def call
      return failure("غير مصرح بحل المتابعة") unless authorized?
      OrderFollowUp.transaction do
        @follow_up.lock!
        raise ActiveRecord::StaleObjectError.new(@follow_up, "resolve") if @lock_version && @follow_up.lock_version != @lock_version.to_i
        return success if @follow_up.resolved?
        return failure("لا يمكن حل هذه المتابعة") unless @follow_up.customer_responded? || !@follow_up.response_required?
        @follow_up.messages.create!(author: @actor, author_role: @actor.role, body: @message, customer_visible: !@internal) if @message.present?
        @follow_up.update!(status: :resolved, resolved_by: @actor, resolved_at: Time.current)
        @follow_up.order.events.create!(actor: @actor, event_type: "follow_up_resolved", customer_visible: true, metadata: { follow_up_id: @follow_up.id })
      end
      success
    rescue ActiveRecord::StaleObjectError
      failure("تم تحديث المتابعة؛ أعد تحميل الصفحة")
    end

    private

    def authorized?
      @follow_up.prescription_clarification? ? @actor&.can_review_prescriptions? : @actor&.can_operate_orders?
    end
    def success = Result.new(success?: true, follow_up: @follow_up, errors: [])
    def failure(message) = Result.new(success?: false, follow_up: @follow_up, errors: [ message ])
  end
end
