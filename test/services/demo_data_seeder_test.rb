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
    assert_equal 10, @manifest.orders
    assert_equal 4, @manifest.prescriptions
    assert_empty ActionMailer::Base.deliveries

    DemoData::Accounts::DEFINITIONS.each_value do |definition|
      user = User.find_by!(email: definition[:email])
      assert_equal definition[:role].to_s, user.role
      assert user.active?
      assert user.two_factor_enabled? unless user.customer?
    end

    assert Product.find_by!(slug: "demo-saline-spray").low_stock?
    assert Product.find_by!(slug: "demo-allergy-tablets").out_of_stock?
    assert Product.find_by!(slug: "demo-rx-tablets-a").requires_prescription?
    assert_equal %w[approved rejected submitted under_review], Prescription.where(order: Order.where("number LIKE 'DEMO-%'")).distinct.order(:status).pluck(:status).sort
    demo_orders = Order.where("number LIKE 'DEMO-%'")
    assert %w[cancelled confirmed delivered out_for_delivery pending_prescription preparing ready_for_delivery rejected submitted].all? { |status| demo_orders.exists?(status:) }
    assert Coupon.exists?(normalized_code: "DEMO10", active: true)
    assert Promotion.exists?(internal_name: "demo:expired", active: false)
    assert_equal 4, DeliveryZone.where("code LIKE 'demo-%'").count
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
      assert_equal order.inventory_reservations.count,
        InventoryMovement.where(reference_type: "InventoryReservation", reference_id: order.inventory_reservation_ids).count
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
      reservations: InventoryReservation.joins(:order).where("orders.number LIKE 'DEMO-%'").count
    }
  end
end
