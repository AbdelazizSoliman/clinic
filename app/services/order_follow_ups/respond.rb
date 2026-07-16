module OrderFollowUps
  class Respond
    Result = Data.define(:success?, :follow_up, :errors)

    def initialize(follow_up:, customer:, body:, lock_version: nil)
      @follow_up, @customer, @body, @lock_version = follow_up, customer, body, lock_version
    end

    def call
      return failure("غير مصرح بالرد") unless @customer&.customer? && @follow_up.order.user_id == @customer.id
      return failure("اكتب ردك") if @body.blank?

      OrderFollowUp.transaction do
        @follow_up.lock!
        raise ActiveRecord::StaleObjectError.new(@follow_up, "respond") if @lock_version && @follow_up.lock_version != @lock_version.to_i
        return success if @follow_up.customer_responded?
        return failure("هذه المتابعة لا تقبل ردًا الآن") unless @follow_up.awaiting_customer?

        @follow_up.messages.create!(author: @customer, author_role: @customer.role, body: @body, customer_visible: true)
        @follow_up.update!(status: :customer_responded, responded_at: Time.current)
        @follow_up.order.events.create!(actor: @customer, event_type: "customer_responded", customer_visible: true, metadata: { follow_up_id: @follow_up.id })
        staff_recipients.each do |recipient|
          Notifications::Create.call(user: recipient, actor: @customer, notifiable: @follow_up, kind: "follow_up_response_received",
            title: "وصل رد العميل", body: "رد جديد للطلب #{@follow_up.order.number}", key: "follow-up-response-#{@follow_up.id}-#{recipient.id}")
        end
      end
      success
    rescue ActiveRecord::StaleObjectError
      failure("تم تحديث المتابعة؛ أعد تحميل الصفحة")
    end

    private

    def staff_recipients
      roles = @follow_up.prescription_clarification? ? %i[pharmacist admin] : %i[order_manager admin]
      User.where(active: true, role: roles)
    end
    def success = Result.new(success?: true, follow_up: @follow_up, errors: [])
    def failure(message) = Result.new(success?: false, follow_up: @follow_up, errors: [ message ])
  end
end
