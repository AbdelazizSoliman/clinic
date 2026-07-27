module Pos
  class OpenSession
    include Support

    def initialize(actor:, opening_cash_cents:, identifier: nil)
      @actor, @opening_cash_cents, @identifier = actor, opening_cash_cents.to_i, identifier
    end

    def call
      return failure(nil, "غير مصرح بتشغيل نقطة البيع") unless @actor&.can_operate_pos?
      return failure(nil, "رصيد بداية الصندوق لا يمكن أن يكون سالبًا") if @opening_cash_cents.negative?
      existing = @actor.cashier_sessions.open.first
      return success(existing) if existing

      session = CashierSession.transaction do
        created = @actor.cashier_sessions.create!(identifier: @identifier.presence || NumberGenerator.session,
          opening_cash_cents: @opening_cash_cents, opened_at: Time.current)
        audit(@actor, created, "pos_session_opened", opening_cash_cents: @opening_cash_cents)
        created
      end
      success(session)
    rescue ActiveRecord::RecordNotUnique
      existing = @actor.cashier_sessions.open.first
      existing ? success(existing) : failure(nil, "تعذر فتح الجلسة؛ حاول مرة أخرى")
    rescue ActiveRecord::RecordInvalid => error
      failure(error.record, error.record.errors.full_messages)
    end
  end
end
