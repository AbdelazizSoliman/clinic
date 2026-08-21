module Loyalty
  class Expire
    include Support
    def initialize(account:, now: Time.current)
      @account, @now = account, now
    end
    def call
      @account.with_lock do
        @account.ledger_entries.earn.where(expires_at: ..@now).order(:expires_at, :id).lock.each do |earn|
          points = earn.remaining_points
          next unless points.positive?
          key = "loyalty-expire:#{earn.id}"
          debit = @account.ledger_entries.find_or_create_by!(idempotency_key: key) do |entry|
            entry.assign_attributes(entry_type: :expire, points:, source: earn.source,
              reason: "انتهاء صلاحية النقاط", occurred_at: @now, reversal_of: earn)
          end
          LoyaltyPointAllocation.find_or_create_by!(earn_entry: earn, debit_entry: debit) { |allocation| allocation.points = points }
        end
      end
      success(@account)
    end
  end
end
