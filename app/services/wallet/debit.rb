module Wallet
  class Debit
    include Support
    def initialize(customer:, amount_cents:, source:, actor:, reason:, idempotency_key:)
      @customer, @amount, @source, @actor, @reason, @key = customer, amount_cents.to_i, source, actor, reason, idempotency_key
    end
    def call
      existing = WalletLedgerEntry.find_by(idempotency_key: @key)
      return success(existing) if existing
      return failure(nil, "قيمة الدفع غير صحيحة") unless @amount.positive?
      account = @customer.ensure_wallet_account!
      entry = account.with_lock do
        if !account.active? || account.balance_cents < @amount
          account.errors.add(:base, "رصيد المحفظة غير كافٍ")
          raise ActiveRecord::RecordInvalid, account
        end
        account.ledger_entries.create!(entry_type: :payment, amount_cents: @amount, source: @source,
          actor: @actor, reason: @reason, occurred_at: Time.current, idempotency_key: @key)
      end
      audit(@actor, account, "wallet_debited", amount_cents: @amount)
      success(entry)
    rescue ActiveRecord::RecordInvalid => error
      failure(account, error.record.errors.full_messages)
    rescue ActiveRecord::RecordNotUnique
      success(WalletLedgerEntry.find_by!(idempotency_key: @key))
    end
  end
end
