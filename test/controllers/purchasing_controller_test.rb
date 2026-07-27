require "test_helper"

class PurchasingControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @supplier = Supplier.create!(name: "مورد الاختبار", code: "CTRL-SUP")
  end

  test "inventory manager and admin access purchasing while other roles receive not found" do
    [ users(:customer), users(:pharmacist), users(:order_manager) ].each do |user|
      sign_in user
      get admin_suppliers_path
      assert_response :not_found
      get admin_purchase_orders_path
      assert_response :not_found
      sign_out user
    end
    sign_in users(:inventory_manager)
    get admin_suppliers_path
    assert_response :success
    get admin_purchase_orders_path
    assert_response :success
  end

  test "inventory manager creates order but cannot approve and admin can" do
    sign_in users(:inventory_manager)
    post admin_purchase_orders_path, params: { purchase_order: { supplier_id: @supplier.id, expected_at: Date.current + 2.days } }
    order = PurchaseOrder.order(:id).last
    assert_redirected_to admin_purchase_order_path(order)
    post admin_purchase_order_items_path(order), params: { purchase_order_item: {
      product_id: products(:featured).id, ordered_quantity: 2, unit_cost: "12.50" } }
    patch submit_admin_purchase_order_path(order), params: { lock_version: order.reload.lock_version }
    assert order.reload.submitted?
    patch approve_admin_purchase_order_path(order), params: { lock_version: order.lock_version }
    assert order.reload.submitted?

    sign_out users(:inventory_manager)
    sign_in users(:admin)
    patch approve_admin_purchase_order_path(order), params: { lock_version: order.lock_version }
    assert order.reload.approved?
  end

  test "receipt endpoint posts stock once" do
    order = Purchasing::CreateOrder.new(actor: users(:inventory_manager), supplier: @supplier).call.purchase_order
    item = Purchasing::AddItem.new(purchase_order: order, actor: users(:inventory_manager), product: products(:featured),
      ordered_quantity: 2, unit_cost_cents: 1_000).call.item
    Purchasing::Submit.new(purchase_order: order, actor: users(:inventory_manager)).call
    Purchasing::Approve.new(purchase_order: order.reload, actor: users(:admin)).call
    before = products(:featured).reload.stock_quantity
    sign_in users(:inventory_manager)
    request_params = { quantities: { item.id.to_s => 1 }, idempotency_key: "controller-receipt", lock_version: order.reload.lock_version }
    post admin_purchase_order_receipts_path(order), params: request_params
    assert_equal before + 1, products(:featured).reload.stock_quantity
    post admin_purchase_order_receipts_path(order), params: request_params
    assert_equal before + 1, products(:featured).reload.stock_quantity
  end

  test "supplier with purchase history remains readable after deactivation" do
    order = Purchasing::CreateOrder.new(actor: users(:inventory_manager), supplier: @supplier).call.purchase_order
    sign_in users(:inventory_manager)
    patch deactivate_admin_supplier_path(@supplier)
    assert_not @supplier.reload.active?
    get admin_purchase_order_path(order)
    assert_response :success
    delete admin_supplier_path(@supplier)
    assert @supplier.reload.persisted?
  end

  test "supplier lifecycle state is changed only through explicit endpoints" do
    sign_in users(:inventory_manager)
    patch admin_supplier_path(@supplier), params: { supplier: { name: "اسم محدث", active: false,
      lock_version: @supplier.lock_version } }
    assert @supplier.reload.active?
    assert_equal "اسم محدث", @supplier.name

    patch deactivate_admin_supplier_path(@supplier)
    assert_not @supplier.reload.active?
    patch admin_supplier_path(@supplier), params: { supplier: { name: "اسم ثان", active: true,
      lock_version: @supplier.lock_version } }
    assert_not @supplier.reload.active?
  end
end
