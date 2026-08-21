module Returns
  class Refund
    include Support
    def initialize(return_request:, actor:, amount_cents:, payment_method:, idempotency_key:, external_reference: nil, notes: nil)
      @request, @actor, @amount, @method = return_request, actor, amount_cents.to_i, payment_method.to_s
      @key, @external_reference, @notes = idempotency_key.to_s, external_reference, notes
    end

    def call
      existing = ::Refund.find_by(idempotency_key: @key)
      return success(existing) if existing
      return failure(@request, "إصدار الاسترداد متاح للمدير فقط") unless @actor&.can_refund_returns?
      refund = nil
      ::Refund.transaction do
        @request.lock!
        raise_error("لا يمكن الاسترداد قبل الاستلام") unless @request.received? || @request.refunded?
        raise_error("قيمة الاسترداد غير صحيحة") unless @amount.positive? && @amount <= @request.remaining_refundable_cents
        validate_method_ceiling!
        status = @method == "external_card" ? :pending : :completed
        session = cash_session
        refund = @request.refunds.create!(source: @request.source, actor: @actor, amount_cents: @amount,
          payment_method: @method, status:, refunded_at: (Time.current if status == :completed),
          external_reference: @external_reference, cashier_session: session, idempotency_key: @key, notes: @notes)
        credit_wallet!(refund) if refund.wallet?
        audit(@actor, @request, "refund_created", refund_id: refund.id, amount_cents: @amount, method: @method)
        audit(@actor, @request, "refund_completed", refund_id: refund.id) if refund.completed?
        Loyalty::ApplyReturnEffects.new(refund:, actor: @actor).call if refund.completed?
        update_request_status!
      end
      success(refund)
    rescue ActiveRecord::RecordInvalid => error
      failure(@request, error.record.errors.full_messages)
    rescue ActiveRecord::RecordNotUnique
      existing = ::Refund.find_by(idempotency_key: @key)
      existing ? success(existing) : failure(@request, "تعذر تسجيل الاسترداد")
    end

    private

    def raise_error(message)
      @request.errors.add(:base, message)
      raise ActiveRecord::RecordInvalid, @request
    end

    def validate_method_ceiling!
      allowed = source_method_capacity
      used = @request.source.return_requests.joins(:refunds).merge(::Refund.where(payment_method: @method, status: %i[pending completed])).sum("refunds.amount_cents")
      raise_error("تتجاوز القيمة المتبقية لطريقة الدفع الأصلية") if @amount > allowed - used
    end

    def source_method_capacity
      source = @request.source
      return source.total_cents if @method == "wallet"
      return source.payments.where(payment_method: @method).sum(:amount_cents) if source.is_a?(PosSale)
      expected = source.cash_on_delivery? ? "cash_on_delivery" : "external_card"
      raise_error("طريقة الاسترداد لا تطابق الدفع الأصلي") unless @method == expected
      source.cash_on_delivery_due_cents
    end

    def credit_wallet!(refund)
      customer = @request.source.is_a?(Order) ? @request.source.user : @request.source.customer
      raise_error("يلزم عميل معرف لإضافة الاسترداد إلى المحفظة") unless customer&.customer?
      result = Wallet::Credit.new(customer:, amount_cents: @amount, entry_type: :refund, source: refund,
        actor: @actor, reason: "استرداد المرتجع #{@request.number}", idempotency_key: "wallet-refund:#{refund.id}").call
      raise_error(result.errors.join("، ")) unless result.success?
      Notifications::Create.call(user: customer, actor: @actor, notifiable: customer.wallet_account,
        kind: "wallet_refund_credited", title: "تم إيداع الاسترداد في المحفظة",
        body: "أضيف مبلغ الاسترداد إلى محفظتك", key: "wallet-refund-credited-#{refund.id}")
    end

    def cash_session
      return unless @method == "cash"
      session = @actor.cashier_sessions.open.order(opened_at: :desc).first
      raise_error("يلزم وجود جلسة صندوق مفتوحة للاسترداد النقدي") unless session
      session
    end

    def update_request_status!
      completed = @request.refunds.completed.sum(:amount_cents)
      return unless completed == @request.refundable_cents
      @request.update!(status: :refunded)
    end
  end
end
