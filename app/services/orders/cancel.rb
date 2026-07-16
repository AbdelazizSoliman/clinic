module Orders
  class Cancel
    Result = Data.define(:success?, :order, :errors)

    def initialize(order:, actor:, reason:, source:, lock_version: nil)
      @order, @actor, @reason, @source, @lock_version = order, actor, reason, source, lock_version
    end

    def call
      return failure("سبب الإلغاء مطلوب") if @reason.blank?
      return failure("غير مصرح بإلغاء الطلب") unless authorized?

      Order.transaction do
        @order.lock!
        raise ActiveRecord::StaleObjectError.new(@order, "cancel") if @lock_version && @order.lock_version != @lock_version.to_i
        return success if @order.cancelled?
        return failure("انتهت مهلة إلغاء الطلب") unless eligible?
        return failure("لا يمكن الإلغاء بعد تجهيز المخزون") if @order.inventory_reservations.consumed.exists?

        Inventory::ReleaseReservations.new(@order).call
        Promotions::ReleaseRedemptions.call(@order)
        @order.update!(status: :cancelled, cancellation_reason: @reason.to_s.squish, cancellation_source: @source,
          cancelled_by: @source == "system" ? nil : @actor, cancelled_at: Time.current)
        event_type = { "customer" => "customer_cancelled", "staff" => "staff_cancelled", "system" => "system_cancelled" }.fetch(@source)
        @order.events.create!(actor: @actor, event_type:, from_status: @order.status_before_last_save, to_status: "cancelled",
          customer_visible: true, metadata: { reason: @reason.to_s.squish.first(300) })
        @order.events.create!(actor: @actor, event_type: "reservations_released", customer_visible: true)
        Notifications::Create.call(user: @order.user, actor: @actor, notifiable: @order, kind: "order_cancelled",
          title: "تم إلغاء الطلب", body: "تم إلغاء الطلب #{@order.number}: #{@reason}", key: "order-cancelled-#{@order.id}")
      end
      success
    rescue ActiveRecord::StaleObjectError
      failure("تم تحديث الطلب؛ أعد تحميل الصفحة")
    end

    private

    def authorized?
      case @source
      when "customer" then @actor&.customer? && @order.user_id == @actor.id
      when "staff" then @actor&.can_operate_orders?
      when "system" then @actor.nil?
      else false
      end
    end
    def eligible? = @source == "customer" ? @order.customer_cancellable? : @order.staff_cancellable?
    def success = Result.new(success?: true, order: @order, errors: [])
    def failure(message) = Result.new(success?: false, order: @order, errors: [ message ])
  end
end
