require "test_helper"

class DrugSafetyAccessTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = users(:admin)
    @pharmacist = users(:pharmacist)
    @customer = users(:customer)
    @alpha = ActiveIngredient.create!(code: "ALPHA", name: "ألفازين")
    @beta = ActiveIngredient.create!(code: "BETA", name: "بيتازول")
    @product_a = rx_product("ACC-A", [ @alpha ])
    @product_b = rx_product("ACC-B", [ @beta ])
    @rule = interaction_rule
    @review = review_for([ @product_a, @product_b ])
    @finding = DrugSafety::Gate.current_findings(@review).first
  end

  test "only a pharmacist can resolve a finding over direct HTTP requests" do
    %i[customer order_manager inventory_manager admin].each do |role|
      sign_in users(role)
      patch staff_safety_finding_path(@finding), params: { safety_action: "overridden", reason: "محاولة" }
      assert_not @finding.reload.resolved?, "#{role} must not resolve a clinical finding"
      sign_out users(role)
    end

    sign_in @pharmacist
    patch staff_safety_finding_path(@finding), params: { safety_action: "overridden", reason: "تجاوز موثق" }
    assert_redirected_to staff_prescription_path(@review.reviewable)
    assert @finding.reload.overridden?
  end

  test "the pharmacist review page renders findings and the customer cannot reach it" do
    sign_in @pharmacist
    get staff_prescription_path(@review.reviewable)
    assert_response :success
    assert_match "تنبيهات سلامة الدواء", response.body
    assert_match DrugSafety::DISCLAIMER, response.body
    sign_out @pharmacist

    sign_in @customer
    get staff_prescription_path(@review.reviewable)
    assert_response :not_found
  end

  test "the POS sale page shows findings and only the pharmacist can clear them" do
    session = Pos::OpenSession.new(actor: @pharmacist, opening_cash_cents: 10_000).call.record
    sale = session.pos_sales.create!(cashier: @pharmacist, number: "TEST-POS-#{SecureRandom.hex(3)}")
    [ @product_a, @product_b ].each { |product| Pos::Cart.new(sale:, actor: @pharmacist).add(product:) }
    finding = DrugSafety::Gate.current_findings(sale.reload.prescription_review).first
    assert finding.blocking?

    sign_in @pharmacist
    get pos_sale_path(sale)
    assert_response :success
    assert_match "تنبيهات سلامة الدواء", response.body
    assert_match "لا يمكن إتمام الصرف", response.body
    sign_out @pharmacist

    sign_in users(:order_manager)
    patch staff_safety_finding_path(finding), params: { safety_action: "acknowledged", reason: "محاولة كاشير" }
    assert finding.reload.open?, "a cashier must not clear a clinical finding"
  end

  test "clinical rule explanations are escaped rather than rendered as markup" do
    injected = DrugSafetyRule.new(code: "XSS-1", version: 1, name: "xss", arabic_label: "<script>alert(1)</script>",
      description: "<img src=x onerror=alert(1)>", rule_type: :duplicate_therapy, severity: :caution,
      created_by: @admin)
    injected.save!
    DrugSafety::RuleLifecycle.activate(rule: injected, actor: @admin)
    twin = rx_product("ACC-A2", [ @alpha ])
    review = review_for([ @product_a, twin ])

    sign_in @pharmacist
    get staff_prescription_path(review.reviewable)
    assert_response :success
    assert_no_match "<script>alert(1)</script>", response.body
    assert_match "&lt;script&gt;", response.body
  end

  test "safety rule administration is admin only" do
    %i[pharmacist inventory_manager order_manager customer].each do |role|
      sign_in users(role)
      get admin_drug_safety_rules_path
      assert_response :not_found, "#{role} must not manage rule definitions"
      sign_out users(role)
    end

    sign_in @admin
    get admin_drug_safety_rules_path
    assert_response :success
    get new_admin_drug_safety_rule_path
    assert_response :success
    get admin_drug_safety_rule_path(@rule)
    assert_response :success
  end

  test "an admin creates, activates and revises a rule through the form" do
    sign_in @admin
    post admin_drug_safety_rules_path, params: { drug_safety_rule: {
      code: "ADM-DUP", version: 1, name: "duplicate", arabic_label: "ازدواج تجريبي",
      description: "قاعدة معدّة محليًا.", rule_type: "duplicate_therapy", severity: "major", blocking: "0",
      conditions_attributes: { "0" => { role: "primary", condition_type: "" } } } }
    rule = DrugSafetyRule.find_by!(code: "ADM-DUP")
    assert_redirected_to admin_drug_safety_rule_path(rule)
    assert_empty rule.conditions
    assert_not rule.active?, "a new rule starts as an inactive draft"

    patch activate_admin_drug_safety_rule_path(rule)
    assert rule.reload.active?

    post revise_admin_drug_safety_rule_path(rule)
    revision = DrugSafetyRule.find_by!(code: "ADM-DUP", version: 2)
    assert_not revision.active?
    assert rule.reload.active?, "the published version stays active until the revision is activated"

    patch activate_admin_drug_safety_rule_path(revision)
    assert revision.reload.active?
    assert_not rule.reload.active?
    assert rule.retired_at.present?
  end

  test "a published rule cannot be edited through the admin controller" do
    sign_in @admin
    patch admin_drug_safety_rule_path(@rule), params: { drug_safety_rule: { severity: "info" } }
    assert_redirected_to admin_drug_safety_rule_path(@rule)
    assert_equal "critical", @rule.reload.severity
  end

  test "clinical profiles are pharmacist only" do
    %i[order_manager inventory_manager admin customer].each do |role|
      sign_in users(role)
      get staff_patient_clinical_profile_path(@customer)
      assert_response :not_found
      sign_out users(role)
    end

    sign_in @pharmacist
    get staff_patient_clinical_profile_path(@customer)
    assert_response :success
    patch staff_patient_clinical_profile_path(@customer),
      params: { patient_clinical_profile: { date_of_birth: "1990-05-05", pregnancy_status: "pregnancy_unknown", lactation_status: "lactation_unknown" } }
    assert_redirected_to staff_patient_clinical_profile_path(@customer)
    assert_equal Date.new(1990, 5, 5), PatientClinicalProfile.find_by(user: @customer).date_of_birth
  end

  test "the safety report is available to pharmacists and admins with filters and CSV" do
    sign_in @pharmacist
    get admin_reports_drug_safety_index_path(preset: "last_30_days")
    assert_response :success
    assert_match "تنبيهات سلامة الدواء", response.body

    get admin_reports_drug_safety_index_path(preset: "last_30_days", format: :csv)
    assert_response :success
    assert_equal "text/csv; charset=utf-8", response.media_type + "; charset=" + response.charset
    assert_match "INT-AB", response.body
    sign_out @pharmacist

    %i[order_manager inventory_manager customer].each do |role|
      sign_in users(role)
      get admin_reports_drug_safety_index_path(preset: "last_30_days")
      assert_response :not_found
      sign_out users(role)
    end
  end

  test "the report summarises by severity, rule type and blocking state" do
    report = ::Reports::DrugSafetySummary.new(::Reports::DateRange.call({ preset: "last_30_days" })).call
    assert_equal 1, report.cards[:findings]
    assert_equal 1, report.cards[:blocking]
    assert_equal 1, report.cards[:open_blocking]
    assert_equal 1, report.severity_counts.fetch("critical", 0)
    assert_equal 1, report.rule_type_counts.fetch("drug_interaction", 0)
    assert_equal 1, report.status_counts.fetch("open", 0)
  end

  private

  def rx_product(reference, ingredients)
    product = Product.create!(name: "منتج #{reference}", slug: "rx-#{reference.downcase}-#{SecureRandom.hex(3)}",
      price: 100, requires_prescription: true, active: true,
      category: categories(:medicines), brand: brands(:eva))
    ingredients.each { |item| product.product_active_ingredients.create!(active_ingredient: item) }
    product.inventory_batches.create!(batch_number: "B-#{reference}-#{SecureRandom.hex(2)}", lot_number: "L-#{reference}",
      expiry_date: 1.year.from_now, received_at: Time.current, original_quantity: 10, on_hand_quantity: 10,
      reserved_quantity: 0, unit_cost_cents: 3000)
    Inventory::BatchAggregate.sync_product!(product)
    product
  end

  def interaction_rule
    rule = DrugSafetyRule.new(code: "INT-AB", version: 1, name: "interaction", arabic_label: "تداخل تجريبي",
      description: "قاعدة تجريبية معدّة محليًا.", rule_type: :drug_interaction, severity: :critical,
      blocking: true, created_by: @admin)
    rule.conditions.build(role: :primary, condition_type: :active_ingredient, active_ingredient: @alpha)
    rule.conditions.build(role: :secondary, condition_type: :active_ingredient, active_ingredient: @beta)
    rule.save!
    DrugSafety::RuleLifecycle.activate(rule:, actor: @admin)
    rule.reload
  end

  def review_for(products)
    cart = @customer.carts.active.first || @customer.carts.create!(currency: "EGP")
    cart.items.delete_all
    products.each { |product| cart.items.create!(product:, quantity: 1) }
    cart.ensure_checkout_submission_token!
    file = Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/prescription.pdf"), "application/pdf")
    result = Orders::CreateFromCart.new(user: @customer, cart:, address_id: addresses(:home).id,
      delivery_method: "standard", payment_method: "cash_on_delivery",
      submission_token: cart.checkout_submission_token, prescription_files: [ file ]).call
    assert result.success?, result.errors.inspect
    Prescriptions::EnsureReview.call(result.order.prescription, actor: @pharmacist)
  end
end
