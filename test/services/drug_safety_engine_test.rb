require "test_helper"

class DrugSafetyEngineTest < ActiveSupport::TestCase
  setup do
    @admin = users(:admin)
    @pharmacist = users(:pharmacist)
    @customer = users(:customer)
    @alpha = ingredient("ALPHA", "ألفازين")
    @beta = ingredient("BETA", "بيتازول")
    @gamma = ingredient("GAMMA", "جامامين")
    @product_a = rx_product("SAFE-A", [ @alpha ])
    @product_b = rx_product("SAFE-B", [ @beta ])
    @product_c = rx_product("SAFE-C", [ @gamma ])
  end

  # ---------- rules ----------

  test "a valid interaction rule activates and enforces one active version per code" do
    rule = interaction_rule(severity: :critical, blocking: true)
    assert rule.active?
    assert_equal "INT-AB v1", rule.identity

    second = DrugSafetyRule.new(rule.attributes.symbolize_keys.slice(:code, :name, :arabic_label, :description,
      :rule_type, :severity).merge(version: 2, active: true, created_by: @admin))
    assert_not second.valid?
    assert_includes second.errors.full_messages.join, "إصدار نشط آخر"
  end

  test "unsupported rule types cannot be activated and are never evaluated" do
    rule = build_rule(code: "RENAL-1", rule_type: :renal_caution, severity: :major)
    assert rule.save
    result = DrugSafety::RuleLifecycle.activate(rule:, actor: @admin)
    assert_not result.success?
    assert_includes result.errors.join, "غير مدعوم"
    assert_not rule.reload.active?
    assert_empty DrugSafety::RuleSet.effective_at(Time.current).rules
  end

  test "blocking requires an actionable severity and invalid enums are refused" do
    rule = build_rule(code: "BAD-1", rule_type: :allergy, severity: :info, blocking: true)
    assert_not rule.valid?
    assert_includes rule.errors.full_messages.join, "خطورة"
    bad_type = build_rule(code: "BAD-2", rule_type: :allergy, severity: :info)
    bad_type.rule_type = "nonsense"
    assert_not bad_type.valid?
    bad_severity = build_rule(code: "BAD-3", rule_type: :allergy, severity: :info)
    bad_severity.severity = "apocalyptic"
    assert_not bad_severity.valid?
  end

  test "revising a published rule preserves the historical version" do
    rule = interaction_rule(severity: :major, blocking: true)
    result = DrugSafety::RuleLifecycle.revise(rule:, actor: @admin)
    assert result.success?, result.errors.join(", ")
    draft = result.rule
    assert_equal 2, draft.version
    assert_not draft.active?
    assert_equal 2, draft.conditions.count
    assert rule.reload.active?

    rule.severity = :info
    assert_not rule.valid?
    assert_includes rule.errors.full_messages.join, "غير قابلة للتعديل"
  end

  # ---------- interactions ----------

  test "interaction matches in both directions and produces exactly one finding" do
    interaction_rule(severity: :critical, blocking: true)
    review = review_for([ @product_a, @product_b ])
    forward = findings_of(review)

    reversed_review = review_for([ @product_b, @product_a ])
    reversed = findings_of(reversed_review)

    assert_equal 1, forward.size
    assert_equal 1, reversed.size
    assert_equal "drug_interaction", forward.first.rule_type
    assert forward.first.blocking?
    assert_equal 2, forward.first.involved_review_item_ids.size
  end

  test "unrelated ingredients produce no interaction finding" do
    interaction_rule(severity: :critical, blocking: true)
    review = review_for([ @product_a, @product_c ])
    assert_empty findings_of(review)
  end

  # ---------- duplicate therapy ----------

  test "duplicate therapy detects the same active ingredient on two lines and ignores unrelated products" do
    duplicate_rule
    twin = rx_product("SAFE-A-TWIN", [ @alpha ])
    review = review_for([ @product_a, twin ])
    findings = findings_of(review)
    assert_equal 1, findings.size
    assert_equal "duplicate_therapy", findings.first.rule_type

    assert_empty findings_of(review_for([ @product_a, @product_c ]))
  end

  # ---------- allergy ----------

  test "allergy matches a recorded allergen and ignores unrelated ones" do
    allergy_rule
    profile = record_profile
    PatientProfiles::RecordAllergy.new(profile:, actor: @pharmacist, active_ingredient: @alpha, severity: "major").call

    findings = findings_of(review_for([ @product_a ]))
    assert_equal 1, findings.size
    assert_equal "allergy", findings.first.rule_type

    assert_empty findings_of(review_for([ @product_c ]))
  end

  test "allergy rules never fire without a structured patient record" do
    allergy_rule
    assert_empty findings_of(review_for([ @product_a ]))
    profile = record_profile(notes: "المريض ذكر حساسية من ألفازين في ملاحظة")
    assert profile.persisted?
    assert_empty findings_of(review_for([ @product_a ])), "notes must never be interpreted as clinical data"
  end

  # ---------- age ----------

  test "minimum age rule fires below the boundary and clears on the birthday" do
    age_rule(minimum: 12)
    profile = record_profile(date_of_birth: Date.current - 12.years + 1.day)
    assert_equal 11, profile.age_years_on(Date.current)
    assert_equal 1, findings_of(review_for([ @product_a ])).size

    profile.update!(date_of_birth: Date.current - 12.years)
    assert_equal 12, profile.reload.age_years_on(Date.current)
    assert_empty findings_of(review_for([ @product_a ]))
  end

  test "maximum age rule fires above the boundary only" do
    age_rule(maximum: 65)
    profile = record_profile(date_of_birth: Date.current - 65.years)
    assert_empty findings_of(review_for([ @product_a ]))

    profile.update!(date_of_birth: Date.current - 66.years)
    assert_equal 1, findings_of(review_for([ @product_a ])).size
  end

  test "pregnancy caution needs an explicit recorded state and is never inferred" do
    state_rule(:pregnancy_caution, "pregnant")
    record_profile(date_of_birth: Date.current - 30.years)
    assert_empty findings_of(review_for([ @product_a ]))

    PatientClinicalProfile.find_by(user: @customer).update!(pregnancy_status: :pregnant)
    findings = findings_of(review_for([ @product_a ]))
    assert_equal 1, findings.size
    assert_equal "pregnancy_caution", findings.first.rule_type
  end

  # ---------- evaluation ----------

  test "evaluation is deterministic, idempotent and free of duplicates" do
    interaction_rule(severity: :critical, blocking: true)
    duplicate_rule
    review = review_for([ @product_a, @product_b ])
    first = review.current_safety_evaluation

    3.times { DrugSafety::Reevaluate.call(review, trigger: :manual, actor: @pharmacist) }
    assert_equal 1, review.safety_evaluations.count
    assert_equal first.id, review.reload.current_safety_evaluation.id
    keys = first.findings.map(&:dedupe_key)
    assert_equal keys.uniq, keys
  end

  test "pure evaluation writes nothing" do
    interaction_rule(severity: :critical, blocking: true)
    review = review_for([ @product_a, @product_b ])
    context = DrugSafety::Context.build(review)
    rule_set = DrugSafety::RuleSet.effective_at(Time.current)

    assert_no_difference [ "DrugSafetyFinding.count", "DrugSafetyEvaluation.count" ] do
      first = DrugSafety::Evaluate.call(context:, rule_set:)
      second = DrugSafety::Evaluate.call(context:, rule_set:)
      assert_equal first.map(&:dedupe_key), second.map(&:dedupe_key)
    end
  end

  test "a changed rule set creates a new evaluation and retires the previous findings" do
    rule = interaction_rule(severity: :critical, blocking: true)
    review = review_for([ @product_a, @product_b ])
    original = review.current_safety_evaluation
    assert_equal 1, original.findings.count

    DrugSafety::RuleLifecycle.deactivate(rule:, actor: @admin)
    DrugSafety::Reevaluate.call(review.reload, trigger: :rules_changed, actor: @pharmacist)

    assert_equal 2, review.reload.safety_evaluations.count
    assert original.reload.superseded_at.present?
    assert original.findings.first.no_longer_applicable?
    assert_empty findings_of(review)
  end

  test "findings snapshot the rule version that produced them" do
    rule = interaction_rule(severity: :critical, blocking: true)
    review = review_for([ @product_a, @product_b ])
    finding = findings_of(review).first

    assert_equal rule.id, finding.drug_safety_rule_id
    assert_equal 1, finding.rule_snapshot["version"]
    assert_equal "critical", finding.rule_snapshot["severity"]
    assert_includes finding.explanation, DrugSafety::DISCLAIMER
  end

  private

  def ingredient(code, name)
    ActiveIngredient.create!(code:, name:, active: true)
  end

  def rx_product(reference, ingredients)
    product = Product.create!(name: "منتج #{reference}", slug: "rx-#{reference.downcase}-#{SecureRandom.hex(3)}",
      price: 100, requires_prescription: true, active: true,
      category: categories(:medicines), brand: brands(:eva))
    ingredients.each { |item| product.product_active_ingredients.create!(active_ingredient: item, active: true) }
    product.inventory_batches.create!(batch_number: "B-#{reference}-#{SecureRandom.hex(2)}", lot_number: "L-#{reference}",
      expiry_date: 1.year.from_now, received_at: Time.current, original_quantity: 10, on_hand_quantity: 10,
      reserved_quantity: 0, unit_cost_cents: 3000)
    Inventory::BatchAggregate.sync_product!(product)
    product
  end

  def build_rule(code:, rule_type:, severity:, blocking: false)
    DrugSafetyRule.new(code:, version: 1, name: code, arabic_label: "قاعدة #{code}",
      description: "قاعدة تجريبية معدّة محليًا للاختبار.", rule_type:, severity:, blocking:, created_by: @admin)
  end

  def activate!(rule)
    rule.save!
    result = DrugSafety::RuleLifecycle.activate(rule:, actor: @admin)
    assert result.success?, result.errors.join(", ")
    rule.reload
  end

  def interaction_rule(severity:, blocking:)
    rule = build_rule(code: "INT-AB", rule_type: :drug_interaction, severity:, blocking:)
    rule.conditions.build(role: :primary, condition_type: :active_ingredient, active_ingredient: @alpha)
    rule.conditions.build(role: :secondary, condition_type: :active_ingredient, active_ingredient: @beta)
    activate!(rule)
  end

  def duplicate_rule
    activate!(build_rule(code: "DUP-1", rule_type: :duplicate_therapy, severity: :caution))
  end

  def allergy_rule
    activate!(build_rule(code: "ALG-1", rule_type: :allergy, severity: :major, blocking: true))
  end

  def age_rule(minimum: nil, maximum: nil)
    rule = build_rule(code: "AGE-1", rule_type: :age_restriction, severity: :major)
    rule.conditions.build(role: :primary, condition_type: :active_ingredient, active_ingredient: @alpha)
    rule.conditions.build(role: :primary, condition_type: :minimum_age_years, numeric_value: minimum) if minimum
    rule.conditions.build(role: :primary, condition_type: :maximum_age_years, numeric_value: maximum) if maximum
    activate!(rule)
  end

  def state_rule(rule_type, state_key)
    rule = build_rule(code: "STATE-1", rule_type:, severity: :caution)
    rule.conditions.build(role: :primary, condition_type: :active_ingredient, active_ingredient: @alpha)
    rule.conditions.build(role: :primary, condition_type: :patient_state, state_key:)
    activate!(rule)
  end

  def record_profile(date_of_birth: nil, notes: nil)
    result = PatientProfiles::Save.new(user: @customer, actor: @pharmacist,
      attributes: { date_of_birth:, notes: }).call
    assert result.success?, result.errors.join(", ")
    result.profile
  end

  def findings_of(review)
    DrugSafety::Gate.current_findings(review).to_a
  end

  def review_for(products)
    order = build_order(products)
    Prescriptions::EnsureReview.call(order.prescription, actor: @pharmacist)
  end

  def build_order(products)
    cart = @customer.carts.active.first || @customer.carts.create!(currency: "EGP")
    cart.items.delete_all
    products.each { |product| cart.items.create!(product:, quantity: 1) }
    cart.ensure_checkout_submission_token!
    file = Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/prescription.pdf"), "application/pdf")
    result = Orders::CreateFromCart.new(user: @customer, cart:, address_id: addresses(:home).id,
      delivery_method: "standard", payment_method: "cash_on_delivery",
      submission_token: cart.checkout_submission_token, prescription_files: [ file ]).call
    assert result.success?, result.errors.inspect
    result.order
  end
end
