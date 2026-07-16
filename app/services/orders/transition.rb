module Orders
  class Transition
    Result = Data.define(:success?, :order, :errors)
    RULES = {
      "submitted" => %w[confirmed cancelled rejected], "confirmed" => %w[preparing cancelled],
      "preparing" => %w[ready_for_delivery], "ready_for_delivery" => %w[out_for_delivery],
      "out_for_delivery" => %w[delivered]
    }.freeze
    EVENTS = { "confirmed" => "order_confirmed", "preparing" => "preparation_started", "ready_for_delivery" => "order_ready", "out_for_delivery" => "out_for_delivery", "delivered" => "delivered", "cancelled" => "cancelled", "rejected" => "rejected" }.freeze

    def initialize(order:, actor:, to_status:, lock_version: nil)
      @order, @actor, @to_status, @lock_version = order, actor, to_status, lock_version
    end

    def call
      return failure("غير مصرح بإدارة الطلبات") unless @actor&.can_operate_orders?
      return Result.new(success?: true, order: @order, errors: []) if @order.status == @to_status

      Order.transaction do
        @order.lock!
        raise ActiveRecord::StaleObjectError.new(@order, "transition") if @lock_version && @order.lock_version != @lock_version.to_i
        return failure("الانتقال المطلوب غير مسموح") unless RULES.fetch(@order.status, []).include?(@to_status)
        return failure("لا يمكن الإلغاء بعد استهلاك المخزون") if @to_status == "cancelled" && @order.inventory_reservations.consumed.exists?

        from = @order.status
        if %w[cancelled rejected].include?(@to_status)
          Inventory::ReleaseReservations.new(@order).call
        elsif @to_status == "ready_for_delivery"
          return failure("تعذر استهلاك الحجز لعدم كفاية المخزون") unless Inventory::ConsumeReservations.new(@order).call
        end
        @order.update!(status: @to_status, confirmed_at: (@to_status == "confirmed" ? Time.current : @order.confirmed_at))
        @order.events.create!(actor: @actor, event_type: EVENTS.fetch(@to_status), from_status: from, to_status: @to_status, customer_visible: true)
        if %w[cancelled rejected].include?(@to_status)
          @order.events.create!(actor: @actor, event_type: "reservations_released", customer_visible: true)
        elsif @to_status == "ready_for_delivery"
          @order.events.create!(actor: @actor, event_type: "reservations_consumed", customer_visible: false)
        end
      end
      Result.new(success?: true, order: @order, errors: [])
    rescue ActiveRecord::StaleObjectError
      failure("تم تحديث الطلب بواسطة مستخدم آخر؛ أعد تحميل الصفحة")
    end

    private

    def failure(message) = Result.new(success?: false, order: @order, errors: [ message ])
  end
end
