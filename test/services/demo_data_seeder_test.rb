require "test_helper"
require "rake"

class DemoDataSeederTest < ActiveSupport::TestCase
  setup do
    @previous_demo_mode = Rails.application.config.x.demo_mode
    @previous_test_override = ENV["DEMO_SEED_TEST"]
    Rails.application.config.x.demo_mode = true
    ENV["DEMO_SEED_TEST"] = "true"
  end

  teardown do
    Rails.application.config.x.demo_mode = @previous_demo_mode
    ENV["DEMO_SEED_TEST"] = @previous_test_override
  end

  test "seed refuses disabled demo mode and test runs without explicit override" do
    Rails.application.config.x.demo_mode = false
    assert_raises(DemoData::Seeder::Refused) { DemoData::Seeder.call }

    Rails.application.config.x.demo_mode = true
    ENV.delete("DEMO_SEED_TEST")
    assert_raises(DemoData::Seeder::Refused) { DemoData::Seeder.call }
  end

  test "rake task refuses to run when demo mode is disabled" do
    Rails.application.load_tasks unless Rake::Task.task_defined?("demo:seed")
    Rails.application.config.x.demo_mode = false
    task = Rake::Task["demo:seed"]
    task.reenable
    _out, error = capture_io { assert_raises(SystemExit) { task.invoke } }
    assert_includes error, "Demo seed refused"
  ensure
    task&.reenable
  end

  test "seed creates representative coherent data without mail delivery" do
    ActionMailer::Base.deliveries.clear
    assert_no_difference("TransactionalEmailDelivery.count") do
      @manifest = DemoData::Seeder.call
    end

    assert_equal 7, @manifest.accounts
    assert_equal 28, @manifest.products
    assert_equal 12, @manifest.orders
    assert_equal 6, @manifest.prescriptions
    assert_equal 3, @manifest.suppliers
    assert_equal 7, @manifest.purchase_orders
    assert_equal 3, @manifest.purchase_receipts
    assert_equal 3, @manifest.cashier_sessions
    assert_equal 6, @manifest.pos_sales
    assert_empty ActionMailer::Base.deliveries
    assert_equal 0, TransactionalEmailDelivery.count

    DemoData::Accounts::DEFINITIONS.each_value do |definition|
      user = User.find_by!(email: definition[:email])
      assert_equal definition[:role].to_s, user.role
      assert user.active?
      assert user.two_factor_enabled? unless user.customer?
    end

    assert Product.find_by!(slug: "demo-saline-spray").low_stock?
    assert Product.find_by!(slug: "demo-allergy-tablets").out_of_stock?
    assert Product.find_by!(slug: "demo-rx-tablets-a").requires_prescription?
    assert_equal %w[approved partially_approved rejected submitted under_review], Prescription.where(order: Order.where("number LIKE 'DEMO-%'")).distinct.order(:status).pluck(:status).sort

    substituted_order = Order.find_by!(number: "DEMO-PRESCRIPTION-SUBSTITUTED")
    substituted_review = PrescriptionReview.find_by!(reviewable: substituted_order.prescription)
    substituted_item = substituted_review.items.sole
    assert substituted_item.substituted?
    assert_not_equal substituted_item.original_product_id, substituted_item.dispensed_product_id
    assert substituted_item.therapeutic_substitution.present?
    assert substituted_order.inventory_reservations.active.exists?(product_id: substituted_item.dispensed_product_id)

    mixed_order = Order.find_by!(number: "DEMO-PRESCRIPTION-MIXED")
    mixed_review = PrescriptionReview.find_by!(reviewable: mixed_order.prescription)
    assert_equal 2, mixed_review.items.count
    assert mixed_review.items.approved.exists?
    assert mixed_review.items.rejected.exists?
    assert mixed_order.submitted?
    assert mixed_order.items.where(requires_prescription: false).exists?

    substituted_sale = PosSale.find_by!(number: "DEMO-POS-RX-SUBSTITUTED")
    substituted_sale_review_item = PrescriptionReview.find_by!(reviewable: substituted_sale).items.sole
    assert substituted_sale_review_item.substituted?
    assert substituted_sale.items.first.prescription_approved?
    demo_orders = Order.where("number LIKE 'DEMO-%'")
    assert %w[cancelled confirmed delivered out_for_delivery pending_prescription preparing ready_for_delivery rejected submitted].all? { |status| demo_orders.exists?(status:) }
    assert Coupon.exists?(normalized_code: "DEMO10", active: true)
    assert Promotion.exists?(internal_name: "demo:expired", active: false)
    assert_equal 4, DeliveryZone.where("code LIKE 'demo-%'").count
    assert PurchaseOrder.find_by!(number: "DEMO-PO-DRAFT").draft?
    assert PurchaseOrder.find_by!(number: "DEMO-PO-SUBMITTED").submitted?
    assert PurchaseOrder.find_by!(number: "DEMO-PO-APPROVED-OVERDUE").approved?
    assert PurchaseOrder.find_by!(number: "DEMO-PO-PARTIAL").partially_received?
    assert PurchaseOrder.find_by!(number: "DEMO-PO-RECEIVED").received?
    assert PurchaseOrder.find_by!(number: "DEMO-PO-CANCELLED").cancelled?
    assert_equal 4, PurchaseOrder.find_by!(number: "DEMO-PO-CANCELLED-PARTIAL").items.first.received_quantity
    assert PosSale.find_by!(number: "DEMO-POS-CASH").completed?
    assert PosSale.find_by!(number: "DEMO-POS-RX").items.first.prescription_approved?
    assert PosSale.find_by!(number: "DEMO-POS-DISCOUNT").manual_discount_cents.positive?
    assert PosSale.find_by!(number: "DEMO-POS-VOID").voided?
    assert CashierSession.find_by!(identifier: "DEMO-POS-OPEN").open?
  end

  test "seeding twice reuses every stable demo record" do
    first = DemoData::Seeder.call
    counts = stable_counts
    second = DemoData::Seeder.call

    assert_equal first.to_h, second.to_h
    assert_equal counts, stable_counts
  end

  test "inventory movements reservations and product quantities agree" do
    DemoData::Seeder.call

    Product.where("slug LIKE 'demo-%'").find_each do |product|
      assert_equal product.stock_quantity, product.inventory_movements.sum(:quantity_delta), product.slug
      assert_operator product.active_reserved_quantity, :<=, product.stock_quantity, product.slug
    end
    Order.where(number: %w[DEMO-READY DEMO-OUT-FOR-DELIVERY DEMO-DELIVERED-OLD]).find_each do |order|
      assert order.inventory_reservations.all?(&:consumed?)
      allocations = InventoryReservationAllocation.where(inventory_reservation_id: order.inventory_reservation_ids)
      assert_equal allocations.count,
        InventoryMovement.where(reference_type: "InventoryReservationAllocation", reference_id: allocations.ids).count
    end
    assert Order.find_by!(number: "DEMO-CANCELLED").inventory_reservations.all?(&:released?)
  end

  test "protected demo identity changes are blocked only in demo mode" do
    DemoData::Seeder.call
    admin = User.find_by!(email: "admin@example.test")
    actor = users(:admin)

    blocked = Admin::Users::Update.new(actor:, user: admin, attributes: { role: :customer }, reason: "اختبار").call
    assert_not blocked.success?
    assert_includes blocked.errors, "لا يمكن تغيير هوية أو صلاحيات حساب العرض المحمي"
    assert admin.reload.admin?

    Rails.application.config.x.demo_mode = false
    allowed = Admin::Users::Update.new(actor:, user: admin, attributes: { email: "changed@example.test" }, reason: "اختبار").call
    assert allowed.success?
  end

  private

  def stable_counts
    {
      users: User.where("email LIKE '%@example.test'").count,
      categories: Category.where("slug LIKE 'demo-%'").count,
      products: Product.where("slug LIKE 'demo-%'").count,
      movements: InventoryMovement.where("idempotency_key LIKE 'demo:%'").count,
      zones: DeliveryZone.where("code LIKE 'demo-%'").count,
      coupons: Coupon.where(normalized_code: %w[DEMO10 VITA25 OLD15 SOONFREE]).count,
      prescriptions: Prescription.joins(:order).where("orders.number LIKE 'DEMO-%'").count,
      orders: Order.where("number LIKE 'DEMO-%'").count,
      reservations: InventoryReservation.joins(:order).where("orders.number LIKE 'DEMO-%'").count,
      suppliers: Supplier.where("code LIKE 'DEMO-SUP-%'").count,
      purchase_orders: PurchaseOrder.where("number LIKE 'DEMO-PO-%'").count,
      purchase_receipts: PurchaseReceipt.where("idempotency_key LIKE 'demo:receipt:%'").count,
      cashier_sessions: CashierSession.where("identifier LIKE 'DEMO-POS-%'").count,
      pos_sales: PosSale.where("number LIKE 'DEMO-POS-%'").count,
      pos_allocations: PosSaleBatchAllocation.joins(pos_sale_item: :pos_sale).where("pos_sales.number LIKE 'DEMO-POS-%'").count
    }
  end
end
