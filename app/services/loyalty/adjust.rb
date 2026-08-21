module Loyalty
  class Adjust
    include Support
    def initialize(customer:, actor:, points:, direction:, reason:, idempotency_key:)
      @customer, @actor, @points, @direction, @reason, @key = customer, actor, points.to_i, direction, reason, idempotency_key
    end
    def call
      existing = LoyaltyLedgerEntry.find_by(idempotency_key: @key)
      return success(existing, points: existing.points) if existing
      return failure(nil, "غير مصرح") unless @actor&.can_manage_loyalty_wallet?
      return failure(nil, "بيانات التعديل غير صحيحة") unless @points.positive? && @reason.present? && %w[credit debit].include?(@direction)
      account = @customer.ensure_loyalty_account!
      entry = account.with_lock do
        return failure(nil, "الرصيد غير كافٍ") if @direction == "debit" && account.points_balance < @points
        account.ledger_entries.create!(entry_type: "adjustment_#{@direction}", points: @points, actor: @actor,
          reason: @reason, occurred_at: Time.current, idempotency_key: @key)
      end
      audit(@actor, account, "loyalty_adjusted", points: @points, direction: @direction)
      success(entry, points: @points)
    rescue ActiveRecord::RecordNotUnique
      entry = LoyaltyLedgerEntry.find_by!(idempotency_key: @key)
      success(entry, points: entry.points)
    end
  end
end
