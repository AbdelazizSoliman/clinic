module Wallet
  class Credit
    include Support
    def initialize(customer:, amount_cents:, entry_type:, source:, actor:, reason:, idempotency_key:)
      @customer, @amount, @type, @source, @actor, @reason, @key = customer, amount_cents.to_i,
        entry_type.to_s, source, actor, reason, idempotency_key
    end
    def call
      existing = WalletLedgerEntry.find_by(idempotency_key: @key)
      return success(existing) if existing
      return failure(nil, "قيمة الائتمان غير صحيحة") unless @amount.positive? && @type.in?(WalletLedgerEntry::CREDIT_TYPES)
      account = @customer.ensure_wallet_account!
      entry = account.with_lock do
        account.ledger_entries.create!(entry_type: @type, amount_cents: @amount, source: @source,
          actor: @actor, reason: @reason, occurred_at: Time.current, idempotency_key: @key)
      end
      audit(@actor, account, "wallet_credited", amount_cents: @amount, entry_type: @type)
      success(entry)
    rescue ActiveRecord::RecordNotUnique
      success(WalletLedgerEntry.find_by!(idempotency_key: @key))
    end
  end
end
