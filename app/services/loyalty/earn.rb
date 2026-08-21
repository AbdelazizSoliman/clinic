module Loyalty
  class Earn
    include Support
    def initialize(source:, customer:, actor: nil, idempotency_key:)
      @source, @customer, @actor, @key = source, customer, actor, idempotency_key
    end
    def call
      existing = LoyaltyLedgerEntry.find_by(idempotency_key: @key)
      return success(existing, points: existing.points) if existing
      return success(nil) unless @customer&.customer? && completed_source?
      rule = LoyaltyRule.current(:earning)
      return success(nil) unless rule
      spend = eligible_spend
      points = (spend / rule.spend_threshold_cents) * rule.points_awarded
      return success(nil) unless spend >= rule.minimum_eligible_spend_cents && points.positive?
      account = @customer.ensure_loyalty_account!
      entry = account.with_lock do
        account.ledger_entries.create!(entry_type: :earn, points:, source: @source, actor: @actor,
          reason: "نقاط شراء #{@source.number}", occurred_at: Time.current,
          expires_at: (Time.current + rule.expiration_days.days if rule.expiration_days), idempotency_key: @key,
          metadata: { rule_code: rule.code, eligible_spend_cents: spend, channel: channel })
      end
      audit(@actor, account, "loyalty_points_earned", points:, source: @source.number)
      Notifications::Create.call(user: @customer, actor: @actor, notifiable: account,
        kind: "loyalty_points_earned", title: "تمت إضافة نقاط", body: "أضيفت #{points} نقطة إلى حسابك",
        key: "loyalty-points-earned-#{entry.id}")
      success(entry, points:)
    rescue ActiveRecord::RecordNotUnique
      entry = LoyaltyLedgerEntry.find_by!(idempotency_key: @key)
      success(entry, points: entry.points)
    end

    private
    def completed_source? = @source.is_a?(Order) ? @source.delivered? : @source.is_a?(PosSale) && @source.completed?
    def channel = @source.is_a?(Order) ? "online" : "pos"
    def eligible_spend
      merchandise = if @source.is_a?(Order)
        @source.subtotal_cents - @source.discount_cents - @source.loyalty_discount_cents + @source.prescription_adjustment_cents
      else
        @source.total_cents - @source.tax_cents
      end
      [ merchandise - @source.wallet_paid_cents, 0 ].max
    end
  end
end
