module Loyalty
  class ReverseRedemption
    include Support
    def initialize(source:, actor:, reason:, idempotency_key:)
      @source, @actor, @reason, @key = source, actor, reason, idempotency_key
    end
    def call
      redeem = LoyaltyLedgerEntry.redeem.find_by(source: @source)
      return success(nil) unless redeem
      existing = LoyaltyLedgerEntry.find_by(idempotency_key: @key)
      return success(existing, points: existing.points) if existing
      entry = redeem.loyalty_account.with_lock do
        redeem.loyalty_account.ledger_entries.create!(entry_type: :redemption_restore, points: redeem.points,
          source: @source, actor: @actor, reversal_of: redeem, reason: @reason,
          occurred_at: Time.current, idempotency_key: @key)
      end
      success(entry, points: entry.points)
    end
  end
end
