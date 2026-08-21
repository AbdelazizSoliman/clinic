module Loyalty
  class ApplyReturnEffects
    include Support
    def initialize(refund:, actor:)
      @refund, @request, @source, @actor = refund, refund.return_request, refund.source, actor
    end
    def call
      customer = @source.is_a?(Order) ? @source.user : @source.customer
      return success(nil) unless customer&.loyalty_account
      account = customer.loyalty_account
      account.with_lock do
        ratio_denominator = [ original_merchandise_value, 1 ].max
        cumulative = @source.return_requests.joins(:refunds).merge(::Refund.completed).sum("refunds.amount_cents")
        reverse_earned!(account, cumulative, ratio_denominator)
        restore_redeemed!(account, cumulative, ratio_denominator)
      end
      success(account)
    end

    private
    def original_merchandise_value
      if @source.is_a?(Order)
        @source.subtotal_cents - @source.discount_cents - @source.loyalty_discount_cents + @source.prescription_adjustment_cents
      else
        @source.total_cents - @source.tax_cents
      end
    end
    def reverse_earned!(account, cumulative, denominator)
      earn = account.ledger_entries.earn.find_by(source: @source)
      return unless earn
      target = [ earn.points * cumulative / denominator, earn.points ].min
      posted = account.ledger_entries.earn_reversal.where(source: @source).sum(:points)
      points = target - posted
      return unless points.positive?
      account.ledger_entries.create!(entry_type: :earn_reversal, points:, source: @source, actor: @actor,
        reversal_of: earn, reason: "عكس نقاط بسبب مرتجع #{@request.number}", occurred_at: Time.current,
        idempotency_key: "return-loyalty-earn-reversal:#{@refund.id}")
      audit(@actor, account, "loyalty_earn_reversed", points:, refund_id: @refund.id)
    end
    def restore_redeemed!(account, cumulative, denominator)
      redeem = account.ledger_entries.redeem.find_by(source: @source)
      return unless redeem
      target = [ redeem.points * cumulative / denominator, redeem.points ].min
      posted = account.ledger_entries.redemption_restore.where(source: @source).sum(:points)
      points = target - posted
      return unless points.positive?
      account.ledger_entries.create!(entry_type: :redemption_restore, points:, source: @source, actor: @actor,
        reversal_of: redeem, reason: "استعادة نقاط مرتجع #{@request.number}", occurred_at: Time.current,
        idempotency_key: "return-loyalty-redemption-restore:#{@refund.id}")
      audit(@actor, account, "loyalty_redemption_restored", points:, refund_id: @refund.id)
    end
  end
end
