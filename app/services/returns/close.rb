module Returns
  class Close
    include Support
    def initialize(return_request:, actor:)
      @request, @actor = return_request, actor
    end
    def call
      return failure(@request, "إغلاق المرتجع متاح للمدير فقط") unless @actor&.can_refund_returns?
      @request.with_lock do
        return success(@request) if @request.closed?
        unless @request.refunded? || (@request.received? && @request.refundable_cents.zero?)
          @request.errors.add(:base, "يلزم إكمال الاسترداد قبل الإغلاق")
          raise ActiveRecord::RecordInvalid, @request
        end
        @request.update!(status: :closed, closed_at: Time.current)
        audit(@actor, @request, "return_closed")
      end
      success(@request)
    rescue ActiveRecord::RecordInvalid => error
      failure(@request, error.record.errors.full_messages)
    end
  end
end
