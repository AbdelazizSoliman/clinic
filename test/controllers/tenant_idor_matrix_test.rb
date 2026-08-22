require "test_helper"

class TenantIdorMatrixTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup { @other = build_other_tenant }

  test "tenant admin cannot guess branch user catalog inventory purchasing promotion or export ids" do
    sign_in users(:admin)
    patch select_branch_path(@other[:branch])
    assert_response :not_found
    get admin_user_path(@other[:admin])
    assert_response :not_found
    get admin_product_path(@other[:product].slug)
    assert_response :not_found
    get admin_inventory_batch_path(@other[:batch])
    assert_response :not_found
    get admin_purchase_order_path(@other[:purchase_order].number)
    assert_response :not_found
    get admin_promotion_path(@other[:promotion])
    assert_response :not_found
    get download_report_export_path(@other[:report_export])
    assert_response :not_found
  end

  test "tenant staff cannot guess order POS session sale return refund or prescription ids" do
    sign_in users(:admin)
    get staff_order_path(@other[:order].number)
    assert_response :not_found
    sign_in users(:admin)
    get pos_session_path(@other[:session].identifier)
    assert_response :not_found
    sign_in users(:admin)
    get pos_sale_path(@other[:sale].number)
    assert_response :not_found
    sign_in users(:admin)
    get staff_return_path(@other[:return_request].number)
    assert_response :not_found
    sign_in users(:admin)
    patch confirm_refund_staff_return_path(@other[:return_request].number, @other[:refund])
    assert_response :not_found

    sign_out users(:admin)
    sign_in users(:pharmacist)
    get staff_prescription_path(@other[:prescription])
    assert_response :not_found
  end

  private

  def build_other_tenant
    organization = Organization.create!(code: "HTTP-OTHER", name: "HTTP Other", active: true,
      timezone: "Africa/Cairo", currency: "EGP", locale: "ar")
    Current.set(organization:) do
      branch = Branch.create!(organization:, code: "HTTP-B", name: "Other", timezone: "Africa/Cairo", default: true)
      admin = User.create!(organization:, default_branch: branch, email: "http-other-admin@example.test", password: "password123",
        first_name: "Other", last_name: "Admin", mobile_number: "01000000661", role: :admin, active: true)
      customer = User.create!(organization:, email: "http-other-customer@example.test", password: "password123",
        first_name: "Other", last_name: "Customer", mobile_number: "01000000662", role: :customer, active: true)
      category = Category.create!(organization_id: organization.id, name: "HTTP Other", slug: "http-other-category", active: true)
      brand = Brand.create!(organization_id: organization.id, name: "HTTP Other", slug: "http-other-brand", active: true)
      product = products(:featured).dup
      product.assign_attributes(organization_id: organization.id, category:, brand:, slug: "http-other-product",
        sku: "HTTP-OTHER", barcode: "996600000001", stock_quantity: 3)
      product.save!
      batch = inventory_batches(:featured_primary).dup
      batch.assign_attributes(organization_id: organization.id, branch:, product:, source_inventory_batch: nil,
        purchase_receipt: nil, purchase_receipt_item: nil, supplier: nil, batch_number: "HTTP-OTHER-BATCH",
        original_quantity: 3, on_hand_quantity: 3, reserved_quantity: 0, returned_quarantine_quantity: 0)
      batch.save!
      supplier = Supplier.create!(organization_id: organization.id, code: "HTTP-SUP", name: "Other Supplier", active: true)
      purchase_order = PurchaseOrder.create!(organization_id: organization.id, branch:, supplier:, created_by: admin,
        number: "HTTP-OTHER-PO", status: :draft, currency: "EGP", subtotal_cents: 0, discount_total_cents: 0,
        tax_total_cents: 0, total_cents: 0)
      cart = Cart.create!(organization_id: organization.id, user: customer, status: :completed, currency: "EGP")
      cents = (product.price * 100).round
      order = Order.create!(organization_id: organization.id, user: customer, branch:, cart:, number: "HTTP-OTHER-ORDER",
        status: :submitted, payment_method: :cash_on_delivery, payment_status: :unpaid, delivery_method: :standard,
        currency: "EGP", subtotal_cents: cents, discount_cents: 0, loyalty_discount_cents: 0, delivery_fee_cents: 0,
        delivery_discount_cents: 0, prescription_adjustment_cents: 0, total_cents: cents, wallet_paid_cents: 0,
        customer_email: customer.email, customer_mobile_number: customer.mobile_number,
        customer_first_name: customer.first_name, customer_last_name: customer.last_name, submitted_at: Time.current)
      session = CashierSession.create!(organization_id: organization.id, branch:, user: admin, identifier: "HTTP-OTHER-SESSION",
        opening_cash_cents: 0, opened_at: Time.current)
      sale = PosSale.create!(organization_id: organization.id, branch:, cashier_session: session, cashier: admin, customer:,
        number: "HTTP-OTHER-POS", subtotal_cents: 0, automatic_discount_cents: 0, manual_discount_cents: 0,
        loyalty_discount_cents: 0, wallet_paid_cents: 0, tax_cents: 0, total_cents: 0)
      return_request = ReturnRequest.create!(organization_id: organization.id, branch:, source: sale, requested_by: admin,
        number: "HTTP-OTHER-RETURN", status: :submitted, submitted_at: Time.current)
      refund = Refund.create!(organization_id: organization.id, return_request:, source: sale, actor: admin,
        amount_cents: 1, payment_method: :cash, status: :pending, idempotency_key: "http-other-refund")
      prescription_id = Prescription.insert!({ organization_id: organization.id, user_id: customer.id, order_id: order.id,
        status: Prescription.statuses[:submitted], scan_status: Prescription.scan_statuses[:pending],
        submitted_at: Time.current, created_at: Time.current, updated_at: Time.current }).rows.first.first
      prescription = Prescription.unscoped.find(prescription_id)
      promotion = Promotion.create!(organization_id: organization.id, internal_name: "http-other-promotion",
        name: "Other Promotion", created_by: admin, updated_by: admin, promotion_type: "cart",
        discount_type: "percentage", discount_value: 10, minimum_subtotal_cents: 0, priority: 1,
        starts_at: 1.day.ago, ends_at: 1.day.from_now, active: true, stackable: false, automatic: true)
      report_export = ReportExport.create!(organization_id: organization.id, user: admin, report_type: "products",
        filters: {}, status: :pending, requested_at: Time.current, deduplication_key: "http-other-export")
      { organization:, branch:, admin:, customer:, product:, batch:, purchase_order:, order:, session:, sale:,
        return_request:, refund:, prescription:, promotion:, report_export: }
    end
  ensure
    Current.reset
  end
end
