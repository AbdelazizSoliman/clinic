module Inventory
  class ExtendReservations
    Result = Data.define(:success?, :expires_at, :errors)

    def initialize(order:, actor:, context: nil, reason: nil, audit: true)
      @order, @actor, @context, @reason, @audit = order, actor, context, reason, audit
    end

    def call
      return failure("غير مصرح بتمديد الحجز") if @context == :admin && !@actor&.admin?
      return failure("سبب التمديد مطلوب") if @context == :admin && @reason.blank?
      expires_at = ReservationExpiryPolicy.expires_at_for(@order, context: @context)
      return failure("لا توجد مدة حجز لهذه الحالة") unless expires_at

      InventoryReservation.transaction do
        @order.inventory_reservations.lock.active.update_all(expires_at:, updated_at: Time.current)
        if @audit
          @order.events.create!(actor: @actor, event_type: "reservations_extended", customer_visible: false,
            metadata: { policy: @context.to_s })
        end
      end
      Result.new(success?: true, expires_at:, errors: [])
    end

    private

    def failure(message) = Result.new(success?: false, expires_at: nil, errors: [ message ])
  end
end
