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
      if @to_status == "cancelled"
        cancelled = Orders::Cancel.new(order: @order, actor: @actor, reason: "إلغاء تشغيلي", source: "staff", lock_version: @lock_version).call
        return Result.new(success?: cancelled.success?, order: @order, errors: cancelled.errors)
      end

      Order.transaction do
        @order.lock!
        raise ActiveRecord::StaleObjectError.new(@order, "transition") if @lock_version && @order.lock_version != @lock_version.to_i
        return failure("الانتقال المطلوب غير مسموح") unless RULES.fetch(@order.status, []).include?(@to_status)
        return failure("لا يمكن الإلغاء بعد استهلاك المخزون") if @to_status == "cancelled" && @order.inventory_reservations.consumed.exists?

        from = @order.status
        if %w[cancelled rejected].include?(@to_status)
          Inventory::ReleaseReservations.new(@order).call
          Promotions::ReleaseRedemptions.call(@order)
        elsif @to_status == "ready_for_delivery"
          return failure("تعذر استهلاك الحجز لعدم كفاية المخزون") unless Inventory::ConsumeReservations.new(@order).call
        end
        @order.update!(status: @to_status, confirmed_at: (@to_status == "confirmed" ? Time.current : @order.confirmed_at))
        @order.inventory_reservations.active.update_all(expires_at: nil, updated_at: Time.current) if @to_status == "confirmed"
        @order.events.create!(actor: @actor, event_type: EVENTS.fetch(@to_status), from_status: from, to_status: @to_status, customer_visible: true)
        notify_customer
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

    def notify_customer
      kinds = { "confirmed" => [ "order_confirmed", "تم تأكيد الطلب" ], "preparing" => [ "order_preparing", "بدأ تجهيز الطلب" ],
        "ready_for_delivery" => [ "order_ready", "الطلب جاهز للتوصيل" ], "out_for_delivery" => [ "order_out_for_delivery", "الطلب في الطريق" ],
        "delivered" => [ "order_delivered", "تم توصيل الطلب" ] }
      kind, title = kinds[@to_status]
      return unless kind
      Notifications::Create.call(user: @order.user, actor: @actor, notifiable: @order, kind:, title:,
        body: "تحديث جديد للطلب #{@order.number}", key: "#{kind}-#{@order.id}")
    end

    def failure(message) = Result.new(success?: false, order: @order, errors: [ message ])
  end
end
