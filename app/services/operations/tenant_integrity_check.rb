module Operations
  class TenantIntegrityCheck < SqlIntegrityCheck
    def call = findings(checks)

    private

    def checks
      tenant_tables = ApplicationRecord.connection.tables.select do |table|
        ApplicationRecord.connection.columns(table).any? { |column| column.name == "organization_id" }
      end
      tenantless = tenant_tables.map do |table|
        [ "tenantless_#{table}".to_sym, :critical, "SELECT id FROM #{ApplicationRecord.connection.quote_table_name(table)} WHERE organization_id IS NULL" ]
      end
      tenantless + [
        [ :branch_organization_mismatch, :critical, <<~SQL.squish ],
          SELECT b.id FROM branches b JOIN organizations o ON o.id = b.organization_id WHERE b.organization_id <> o.id
        SQL
        [ :batch_branch_mismatch, :critical, "SELECT ib.id FROM inventory_batches ib JOIN branches b ON b.id=ib.branch_id WHERE ib.organization_id<>b.organization_id" ],
        [ :batch_product_mismatch, :critical, "SELECT ib.id FROM inventory_batches ib JOIN products p ON p.id=ib.product_id WHERE ib.organization_id<>p.organization_id" ],
        [ :order_branch_or_user_mismatch, :critical, "SELECT o.id FROM orders o JOIN branches b ON b.id=o.branch_id JOIN users u ON u.id=o.user_id WHERE o.organization_id<>b.organization_id OR o.organization_id<>u.organization_id" ],
        [ :pos_branch_mismatch, :critical, "SELECT p.id FROM pos_sales p JOIN branches b ON b.id=p.branch_id WHERE p.organization_id<>b.organization_id" ],
        [ :purchase_order_reference_mismatch, :critical, "SELECT po.id FROM purchase_orders po JOIN branches b ON b.id=po.branch_id JOIN suppliers s ON s.id=po.supplier_id WHERE po.organization_id<>b.organization_id OR po.organization_id<>s.organization_id" ],
        [ :wallet_account_mismatch, :critical, "SELECT e.id FROM wallet_ledger_entries e JOIN wallet_accounts a ON a.id=e.wallet_account_id WHERE e.organization_id<>a.organization_id" ],
        [ :loyalty_account_mismatch, :critical, "SELECT e.id FROM loyalty_ledger_entries e JOIN loyalty_accounts a ON a.id=e.loyalty_account_id WHERE e.organization_id<>a.organization_id" ],
        [ :prescription_user_mismatch, :critical, "SELECT p.id FROM prescriptions p JOIN users u ON u.id=p.user_id WHERE p.organization_id<>u.organization_id" ],
        [ :return_source_mismatch, :critical, <<~SQL.squish ]
          SELECT r.id FROM return_requests r LEFT JOIN orders o ON r.source_type='Order' AND o.id=r.source_id
          LEFT JOIN pos_sales p ON r.source_type='PosSale' AND p.id=r.source_id
          WHERE (o.id IS NOT NULL AND r.organization_id<>o.organization_id) OR (p.id IS NOT NULL AND r.organization_id<>p.organization_id)
        SQL
      ]
    end
  end
end
