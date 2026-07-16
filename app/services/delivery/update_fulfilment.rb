module Delivery
  class UpdateFulfilment
    Result = Data.define(:success?, :fulfilment, :errors)
    RULES = { "assigned" => %w[picking], "picking" => %w[packed], "packed" => %w[dispatched], "dispatched" => %w[delivered] }.freeze
    EVENTS = { "picking" => "fulfilment_picking", "packed" => "fulfilment_packed", "dispatched" => "delivery_dispatched", "delivered" => "delivery_completed" }.freeze
    def initialize(fulfilment:, actor:, to_status:, lock_version: nil)
      @fulfilment, @actor, @to_status, @lock_version = fulfilment, actor, to_status, lock_version
    end
    def call
      return failure("غير مصرح بإدارة التوصيل") unless @actor&.can_manage_delivery?
      return success if @fulfilment.status == @to_status
      Fulfilment.transaction do
        @fulfilment.lock!
        raise ActiveRecord::StaleObjectError.new(@fulfilment, "transition") if @lock_version && @fulfilment.lock_version != @lock_version.to_i
        return failure("انتقال مهمة التوصيل غير مسموح") unless RULES.fetch(@fulfilment.status, []).include?(@to_status)
        timestamps = { picked_at: :picking, dispatched_at: :dispatched, delivered_at: :delivered }.filter_map { |field, state| [ field, Time.current ] if @to_status == state.to_s }.to_h
        @fulfilment.update!(status: @to_status, **timestamps)
        @fulfilment.order.events.create!(actor: @actor, event_type: EVENTS.fetch(@to_status), customer_visible: %w[dispatched delivered].include?(@to_status))
      end
      success
    rescue ActiveRecord::StaleObjectError
      failure("تم تحديث مهمة التوصيل بواسطة مستخدم آخر")
    end
    private
    def success = Result.new(success?: true, fulfilment: @fulfilment, errors: [])
    def failure(message) = Result.new(success?: false, fulfilment: @fulfilment, errors: [ message ])
  end
end
