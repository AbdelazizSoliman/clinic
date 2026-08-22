require "test_helper"

class TenantServiceIsolationTest < ActiveSupport::TestCase
  setup do
    @default = organizations(:default)
    @other = Organization.create!(code: "SERVICE-OTHER", name: "Service Other", active: true,
      timezone: "Africa/Cairo", currency: "EGP", locale: "ar")
    @other_records = Current.set(organization: @other) do
      branch = Branch.create!(organization: @other, code: "SERVICE-B", name: "Other", timezone: "Africa/Cairo", default: true)
      admin = User.create!(organization: @other, default_branch: branch, email: "service-other-admin@example.test",
        password: "password123", first_name: "Other", last_name: "Admin", mobile_number: "01000000771", role: :admin, active: true)
      customer = User.create!(organization: @other, email: "service-other-customer@example.test", password: "password123",
        first_name: "Other", last_name: "Customer", mobile_number: "01000000772", role: :customer, active: true)
      category = Category.create!(organization_id: @other.id, name: "Other", slug: "service-other-category", active: true)
      brand = Brand.create!(organization_id: @other.id, name: "Other", slug: "service-other-brand", active: true)
      product = products(:featured).dup
      product.assign_attributes(organization_id: @other.id, category:, brand:, slug: "service-other-product",
        sku: "SERVICE-OTHER", barcode: "997700000001", stock_quantity: 0)
      product.save!
      supplier = Supplier.create!(organization_id: @other.id, code: "SERVICE-SUP", name: "Other Supplier", active: true)
      { branch:, admin:, customer:, product:, supplier: }
    end
    Current.organization = @default
    Current.branch = branches(:main)
  end

  teardown { Current.reset }

  test "purchasing and POS reject cross tenant inputs before writes" do
    assert_no_difference -> { PurchaseOrder.count } do
      result = Purchasing::CreateOrder.new(actor: users(:inventory_manager), supplier: @other_records[:supplier], attributes: {}).call
      refute result.success?
    end
    session = CashierSession.new(organization_id: @default.id, branch: branches(:main), user: users(:order_manager))
    sale = PosSale.new(organization_id: @default.id, branch: branches(:main), cashier_session: session,
      cashier: users(:order_manager), number: "TENANT-ISOLATION-POS")
    assert_no_difference -> { PosSaleItem.count } do
      result = Pos::Cart.new(sale:, actor: users(:order_manager)).add(product: @other_records[:product])
      refute result.success?
    end
  end

  test "stock transfer rejects a destination from another tenant" do
    transfer = StockTransfer.new(organization_id: @default.id, number: "CROSS-TENANT", source_branch: branches(:main),
      destination_branch: @other_records[:branch], created_by: users(:inventory_manager))
    result = StockTransfers::Workflow.new(transfer:, actor: users(:inventory_manager), action: :submit).call
    refute result.success?
    assert_match(/مؤسسات/, result.errors.join)
  end

  test "wallet and loyalty reject cross tenant sources without ledger effects" do
    source = PosSale.new(organization_id: @other.id, branch: @other_records[:branch], cashier: @other_records[:admin],
      number: "OTHER-SOURCE")
    customer = users(:customer)
    assert_no_difference -> { WalletLedgerEntry.count } do
      refute Wallet::Credit.new(customer:, amount_cents: 100, entry_type: :credit, source:,
        actor: users(:admin), reason: "cross", idempotency_key: "cross-wallet").call.success?
    end
    assert_no_difference -> { LoyaltyLedgerEntry.count } do
      refute Loyalty::Redeem.new(customer:, source:, requested_points: 10, maximum_value_cents: 100,
        actor: users(:admin), idempotency_key: "cross-loyalty").call.success?
    end
  end

  test "model and database reject cross tenant batch relationships" do
    batch = inventory_batches(:featured_primary).dup
    batch.assign_attributes(organization_id: @default.id, branch: branches(:main), product: @other_records[:product],
      batch_number: "CROSS-BATCH")
    refute batch.valid?
    assert batch.errors[:product].present?
  end
end
