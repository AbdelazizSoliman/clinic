module Admin
  module Reports
    class LoyaltyWalletController < BaseController
      before_action -> { authorize_capability!(:can_view_loyalty_wallet_reports?) }
      def index
        @loyalty = LoyaltyLedgerEntry.where(occurred_at: @date_range.range)
        @wallet = WalletLedgerEntry.where(occurred_at: @date_range.range)
        @points_balance = LoyaltyAccount.joins(:ledger_entries).sum(Arel.sql(LoyaltyLedgerEntry.balance_sql))
        @wallet_liability_cents = WalletAccount.joins(:ledger_entries).sum(Arel.sql(WalletLedgerEntry.balance_sql))
        return unless request.format.csv?
        rows = @loyalty.order(:occurred_at).map { |entry| [ "loyalty", entry.occurred_at, entry.entry_type, entry.points, entry.source_type, entry.source_id ] }
        rows += @wallet.order(:occurred_at).map { |entry| [ "wallet", entry.occurred_at, entry.entry_type, entry.amount_cents, entry.source_type, entry.source_id ] }
        export = ::Reports::CsvExporter.call(headers: %w[domain date type amount source_type source_id], rows:)
        send_data export.content, type: "text/csv; charset=utf-8", filename: "loyalty-wallet.csv"
      end
    end
  end
end
