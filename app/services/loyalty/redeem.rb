module Loyalty
  class Redeem
    include Support
    def initialize(customer:, source:, requested_points:, maximum_value_cents:, actor: nil, idempotency_key:)
      @customer, @source, @requested, @maximum, @actor, @key = customer, source, requested_points.to_i,
        maximum_value_cents.to_i, actor, idempotency_key
    end
    def call
      return failure(nil, "لا يمكن استبدال نقاط عبر مؤسسات مختلفة") unless Operations::TenantGuard.same_organization?(@customer, @source, @actor)
      existing = LoyaltyLedgerEntry.find_by(idempotency_key: @key)
      return success(existing, points: existing.points, value_cents: existing.metadata["value_cents"].to_i) if existing
      return success(nil) if @requested.zero?
      rule = LoyaltyRule.current(:redemption)
      return failure(nil, "لا توجد قاعدة استبدال فعالة") unless rule
      points = normalized_points(rule)
      value = points / rule.redemption_points * rule.redemption_value_cents
      return failure(nil, "قيمة الاستبدال غير صالحة") unless points.positive? && value.positive? && value <= @maximum
      account = @customer.ensure_loyalty_account!
      entry = account.with_lock do
        expire_due!(account)
        raise ActiveRecord::RecordInvalid, account if account.points_balance < points
        record = account.ledger_entries.create!(entry_type: :redeem, points:, source: @source, actor: @actor,
          reason: "استبدال نقاط", occurred_at: Time.current, idempotency_key: @key,
          metadata: { rule_code: rule.code, value_cents: value })
        allocate!(account, record, points)
        record
      end
      audit(@actor, account, "loyalty_points_redeemed", points:, value_cents: value)
      success(entry, points:, value_cents: value)
    rescue ActiveRecord::RecordInvalid
      failure(nil, "رصيد النقاط غير كافٍ")
    end

    private
    def normalized_points(rule)
      points = @requested
      points = [ points, rule.maximum_redemption_points ].min if rule.maximum_redemption_points
      return 0 if rule.minimum_redemption_points && points < rule.minimum_redemption_points
      units = [ @maximum / rule.redemption_value_cents, points / rule.redemption_points ].min
      units * rule.redemption_points
    end
    def expire_due!(account) = Loyalty::Expire.new(account:, now: Time.current).call
    def allocate!(account, debit, remaining)
      credits = account.ledger_entries.where(entry_type: LoyaltyLedgerEntry::CREDIT_TYPES)
        .where("expires_at IS NULL OR expires_at > ?", Time.current).order(Arel.sql("expires_at ASC NULLS LAST"), :occurred_at, :id).lock
      credits.each do |credit|
        quantity = [ remaining, credit.remaining_points ].min
        next unless quantity.positive?
        LoyaltyPointAllocation.create!(earn_entry: credit, debit_entry: debit, points: quantity)
        remaining -= quantity
        break if remaining.zero?
      end
      raise ActiveRecord::RecordInvalid, account if remaining.positive?
    end
  end
end
