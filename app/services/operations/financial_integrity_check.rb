module Operations
  class FinancialIntegrityCheck < SqlIntegrityCheck
    def call
      findings([
        [ :negative_wallet_balance, :critical, <<~SQL.squish ],
          SELECT a.id FROM wallet_accounts a WHERE (SELECT COALESCE(SUM(CASE WHEN e.entry_type IN (0,2,3,5) THEN e.amount_cents ELSE -e.amount_cents END),0) FROM wallet_ledger_entries e WHERE e.wallet_account_id=a.id)<0
        SQL
        [ :negative_loyalty_balance, :critical, <<~SQL.squish ],
          SELECT a.id FROM loyalty_accounts a WHERE (SELECT COALESCE(SUM(CASE WHEN e.entry_type IN (0,4,5) THEN e.points ELSE -e.points END),0) FROM loyalty_ledger_entries e WHERE e.loyalty_account_id=a.id)<0
        SQL
        [ :duplicate_wallet_idempotency, :critical, "SELECT MIN(id) id FROM wallet_ledger_entries GROUP BY organization_id,idempotency_key HAVING COUNT(*)>1" ],
        [ :duplicate_loyalty_idempotency, :critical, "SELECT MIN(id) id FROM loyalty_ledger_entries GROUP BY organization_id,idempotency_key HAVING COUNT(*)>1" ],
        [ :refund_above_return_total, :critical, "SELECT r.id FROM return_requests r JOIN refunds f ON f.return_request_id=r.id AND f.status=1 GROUP BY r.id HAVING SUM(f.amount_cents)>(SELECT COALESCE(SUM(i.refundable_amount_cents),0) FROM return_items i WHERE i.return_request_id=r.id)" ],
        [ :refund_tenant_mismatch, :critical, "SELECT f.id FROM refunds f JOIN return_requests r ON r.id=f.return_request_id WHERE f.organization_id<>r.organization_id" ]
      ])
    end
  end
end
