module OrderFollowUps
  class Open
    Result = Data.define(:success?, :follow_up, :errors)

    def initialize(order:, actor:, kind:, subject:, customer_message:, internal_notes: nil, due_at: nil)
      @order, @actor, @kind, @subject = order, actor, kind, subject
      @customer_message, @internal_notes, @due_at = customer_message, internal_notes, due_at
    end

    def call
      return failure("غير مصرح بفتح المتابعة") unless authorized?

      follow_up = nil
      OrderFollowUp.transaction do
        @order.lock!
        follow_up = @order.follow_ups.create!(prescription: prescription_reference, opened_by: @actor, kind: @kind,
          status: :awaiting_customer, subject: @subject, customer_message: @customer_message,
          internal_notes: @internal_notes, response_required: true, due_at: safe_due_at)
        follow_up.messages.create!(author: @actor, author_role: @actor.role, body: @customer_message, customer_visible: true)
        @order.events.create!(actor: @actor, event_type: "follow_up_opened", customer_visible: true, metadata: { follow_up_id: follow_up.id })
        Inventory::ExtendReservations.new(order: @order, actor: @actor, context: :follow_up, audit: false).call
        Notifications::Create.call(user: @order.user, actor: @actor, notifiable: follow_up, kind: "follow_up_requested",
          title: "مطلوب ردك على الطلب", body: @subject, key: "follow-up-requested-#{follow_up.id}")
      end
      Result.new(success?: true, follow_up:, errors: [])
    rescue ActiveRecord::RecordInvalid => error
      failure(error.record.errors.full_messages.join("، "))
    end

    private

    def authorized?
      return false unless @actor&.staff?
      return @actor.can_review_prescriptions? if @kind.to_s == "prescription_clarification"

      @actor.can_operate_orders?
    end
    def prescription_reference = @kind.to_s == "prescription_clarification" ? @order.prescription : nil
    def safe_due_at = [ @due_at, Time.current + 7.days ].compact.min || Time.current + 24.hours
    def failure(message) = Result.new(success?: false, follow_up: nil, errors: [ message ])
  end
end
