module Pos
  class CloseSession
    include Support

    DIFFERENCE_NOTE_THRESHOLD_CENTS = 500

    def initialize(session:, actor:, counted_cash_cents:, notes: nil, lock_version: nil)
      @session, @actor, @counted, @notes, @lock_version = session, actor, counted_cash_cents.to_i, notes, lock_version
    end

    def call
      return failure(@session, "غير مصرح بإغلاق الجلسة") unless authorized?
      return failure(@session, "المبلغ المعدود لا يمكن أن يكون سالبًا") if @counted.negative?

      CashierSession.transaction do
        @session.lock!
        raise ActiveRecord::StaleObjectError.new(@session, "close") if @lock_version && @session.lock_version != @lock_version.to_i
        return success(@session) if @session.closed?
        return failure(@session, "يجب إلغاء مسودات البيع قبل إغلاق الجلسة") if @session.pos_sales.draft.exists?
        expected = @session.expected_cash
        difference = @counted - expected
        if difference.abs >= DIFFERENCE_NOTE_THRESHOLD_CENTS && @notes.to_s.squish.blank?
          return failure(@session, "ملاحظة التسوية مطلوبة عند وجود فرق 5 جنيهات أو أكثر")
        end
        @session.update!(status: :closed, closed_at: Time.current, expected_cash_cents: expected,
          closing_cash_counted_cents: @counted, cash_difference_cents: difference, notes: @notes.to_s.squish.presence)
        audit(@actor, @session, "pos_session_closed",
          expected_cash_cents: expected, counted_cash_cents: @counted, difference_cents: difference)
      end
      success(@session)
    rescue ActiveRecord::StaleObjectError
      failure(@session, "تم تحديث الجلسة بواسطة مستخدم آخر؛ أعد تحميل الصفحة")
    rescue ActiveRecord::RecordInvalid => error
      failure(@session, error.record.errors.full_messages)
    end

    private

    def authorized? = @actor && (@actor.id == @session.user_id || @actor.admin?)
  end
end
