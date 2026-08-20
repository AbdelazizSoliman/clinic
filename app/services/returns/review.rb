module Returns
  class Review
    include Support
    def initialize(return_request:, actor:, approve:, notes: nil)
      @request, @actor, @approve, @notes = return_request, actor, approve, notes
    end
    def call
      return failure(@request, "غير مصرح بمراجعة المرتجع") unless @actor&.can_review_returns?
      ReturnRequest.transaction do
        @request.lock!
        return success(@request) if (@approve && @request.approved?) || (!@approve && @request.rejected?)
        raise ActiveRecord::RecordInvalid, @request unless @request.submitted? || @request.under_review?
        @request.items.lock.each { |item| item.update!(approved_quantity: @approve ? item.requested_quantity : 0) }
        @request.update!(status: @approve ? :approved : :rejected, reviewed_by: @actor,
          reviewed_at: Time.current, internal_notes: @notes)
        audit(@actor, @request, @approve ? "return_approved" : "return_rejected")
      end
      success(@request)
    rescue ActiveRecord::RecordInvalid => error
      failure(@request, error.record.errors.full_messages)
    end
  end
end
