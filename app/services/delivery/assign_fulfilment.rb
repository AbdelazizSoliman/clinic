module Delivery
  class AssignFulfilment
    Result = Data.define(:success?, :fulfilment, :errors)
    def initialize(order:, actor:, assigned_to:, internal_notes: nil, lock_version: nil)
      @order, @actor, @assigned_to, @internal_notes, @lock_version = order, actor, assigned_to, internal_notes, lock_version
    end
    def call
      return failure("غير مصرح بإسناد التوصيل") unless @actor&.can_assign_delivery?
      return failure("المسؤول المحدد غير مصرح له") unless @assigned_to&.can_manage_delivery?
      fulfilment = nil
      Fulfilment.transaction do
        fulfilment = @order.fulfilment || @order.build_fulfilment(delivery_zone: @order.delivery_zone, delivery_slot: @order.delivery_slot)
        fulfilment.lock! if fulfilment.persisted?
        raise ActiveRecord::StaleObjectError.new(fulfilment, "assign") if @lock_version && fulfilment.lock_version != @lock_version.to_i
        return success(fulfilment) if fulfilment.assigned? && fulfilment.assigned_to_id == @assigned_to.id
        fulfilment.update!(status: :assigned, assigned_to: @assigned_to, assigned_by: @actor, assigned_at: Time.current, internal_notes: @internal_notes.to_s.squish.presence)
        @order.events.create!(actor: @actor, event_type: "fulfilment_assigned", customer_visible: false, metadata: { assignee_id: @assigned_to.id })
        Notifications::Create.call(user: @assigned_to, actor: @actor, notifiable: @order, kind: "delivery_assigned",
          title: "تم إسناد طلب للتوصيل", body: "الطلب #{@order.number}", key: "delivery-assigned-#{@order.id}-#{@assigned_to.id}")
      end
      success(fulfilment)
    rescue ActiveRecord::StaleObjectError
      failure("تم تحديث مهمة التوصيل بواسطة مستخدم آخر")
    end
    private
    def success(value) = Result.new(success?: true, fulfilment: value, errors: [])
    def failure(message) = Result.new(success?: false, fulfilment: @order.fulfilment, errors: [ message ])
  end
end
