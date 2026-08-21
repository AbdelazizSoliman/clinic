module Wallet
  class Adjust
    include Support
    def initialize(customer:, actor:, amount_cents:, direction:, reason:, idempotency_key:)
      @customer, @actor, @amount, @direction, @reason, @key = customer, actor, amount_cents.to_i,
        direction.to_s, reason, idempotency_key
    end
    def call
      existing = WalletLedgerEntry.find_by(idempotency_key: @key)
      return success(existing) if existing
      return failure(nil, "غير مصرح") unless @actor&.can_manage_loyalty_wallet?
      return failure(nil, "بيانات التعديل غير صحيحة") unless @amount.positive? && @reason.present? && @direction.in?(%w[credit debit])
      return Wallet::Credit.new(customer: @customer, amount_cents: @amount, entry_type: :adjustment_credit,
        source: nil, actor: @actor, reason: @reason, idempotency_key: @key).call if @direction == "credit"
      account = @customer.ensure_wallet_account!
      entry = account.with_lock do
        if account.balance_cents < @amount
          account.errors.add(:base, "رصيد المحفظة غير كافٍ")
          raise ActiveRecord::RecordInvalid, account
        end
        account.ledger_entries.create!(entry_type: :adjustment_debit, amount_cents: @amount,
          actor: @actor, reason: @reason, occurred_at: Time.current, idempotency_key: @key)
      end
      audit(@actor, account, "wallet_adjusted", amount_cents: @amount, direction: @direction)
      success(entry)
    rescue ActiveRecord::RecordInvalid => error
      failure(account, error.record.errors.full_messages)
    end
  end
end
