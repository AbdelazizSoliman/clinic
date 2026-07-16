module Inventory
  class ExpireReservations
    Result = Data.define(:processed, :failed)

    def call(now: Time.current)
      order_ids = InventoryReservation.active.where(expires_at: ...now).distinct.pluck(:order_id)
      processed = 0
      failed = []
      order_ids.each do |order_id|
        order = Order.find_by(id: order_id)
        next unless order&.pending_prescription? || order&.submitted?
        reason = order.pending_prescription? ? "انتهت مهلة مراجعة الروشتة أو الرد المطلوب" : "انتهت مدة حجز المخزون قبل تأكيد الطلب"
        result = Orders::Cancel.new(order:, actor: nil, reason:, source: "system").call
        if result.success?
          order.events.create!(event_type: "reservations_expired", customer_visible: true)
          processed += 1
        else
          failed << order_id
        end
      rescue ActiveRecord::RecordInvalid, ActiveRecord::StaleObjectError
        failed << order_id
      end
      Result.new(processed:, failed:)
    end
  end
end
