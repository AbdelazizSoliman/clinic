require "test_helper"

class DrugSafetyWorkflowTest < ActiveSupport::TestCase
  setup do
    @admin = users(:admin)
    @pharmacist = users(:pharmacist)
    @manager = users(:order_manager)
    @customer = users(:customer)
    @alpha = ActiveIngredient.create!(code: "ALPHA", name: "ألفازين")
    @beta = ActiveIngredient.create!(code: "BETA", name: "بيتازول")
    @gamma = ActiveIngredient.create!(code: "GAMMA", name: "جامامين")
    @product_a = rx_product("WF-A", [ @alpha ])
    @product_b = rx_product("WF-B", [ @beta ])
    @safe_substitute = rx_product("WF-SAFE", [ @gamma ])
    @twin_of_a = rx_product("WF-A2", [ @alpha ])
  end

  # ---------- prescription review ----------

  test "approval proceeds normally when no rule matches" do
    interaction_rule(blocking: true)
    review = review_for([ @product_a ])
    item = review.items.first
    result = decide(item, "approved")
    assert result.success?, result.errors.join(", ")
    assert item.reload.approved?
  end

  test "an unresolved critical finding blocks approval but never blocks rejection" do
    interaction_rule(blocking: true)
    review = review_for([ @product_a, @product_b ])
    item = review.items.order(:id).first

    blocked = decide(item, "approved")
    assert_not blocked.success?
    assert_includes blocked.errors.join, "تنبيهات سلامة حرجة"
    assert item.reload.pending?

    rejected = decide(item, "rejected")
    assert rejected.success?, rejected.errors.join(", ")
    assert item.reload.rejected?
  end

  test "approval proceeds once a pharmacist acknowledges the blocking finding" do
    interaction_rule(blocking: true)
    review = review_for([ @product_a, @product_b ])
    item = review.items.order(:id).first
    finding = DrugSafety::Gate.blocking_findings(review).first

    result = DrugSafety::Acknowledge.new(finding:, actor: @pharmacist, action: "overridden",
      reason: "تقييم سريري موثق للاختبار").call
    assert result.success?, result.errors.join(", ")
    assert finding.reload.overridden?
    assert_equal @pharmacist, finding.resolved_by
    assert_equal 1, finding.acknowledgements.count

    assert decide(item, "approved").success?
  end

  test "non-pharmacists cannot resolve findings" do
    interaction_rule(blocking: true)
    review = review_for([ @product_a, @product_b ])
    finding = DrugSafety::Gate.blocking_findings(review).first

    [ @manager, @admin, @customer, users(:inventory_manager) ].each do |actor|
      result = DrugSafety::Acknowledge.new(finding:, actor:, action: "acknowledged", reason: "محاولة").call
      assert_not result.success?, "#{actor.role} must not resolve clinical findings"
    end
    assert finding.reload.open?
  end

  test "a blocking finding requires a documented reason" do
    interaction_rule(blocking: true)
    review = review_for([ @product_a, @product_b ])
    finding = DrugSafety::Gate.blocking_findings(review).first

    assert_not DrugSafety::Acknowledge.new(finding:, actor: @pharmacist, action: "acknowledged", reason: " ").call.success?
    assert finding.reload.open?
  end

  # ---------- substitution ----------

  test "substitution retains the old evaluation and re-evaluates the substitute product" do
    interaction_rule(blocking: false, severity: :caution)
    review = review_for([ @product_a, @product_b ])
    first_evaluation = review.current_safety_evaluation
    assert_equal 1, first_evaluation.findings.count

    item = review.items.find_by!(original_product: @product_b)
    result = decide(item, "substituted", substitute_product: @safe_substitute)
    assert result.success?, result.errors.join(", ")

    review.reload
    assert_equal first_evaluation.id, DrugSafetyEvaluation.find(first_evaluation.id).id
    assert first_evaluation.reload.superseded_at.present?
    assert first_evaluation.findings.first.no_longer_applicable?
    assert_operator review.safety_evaluations.count, :>=, 2
    assert_empty DrugSafety::Gate.current_findings(review).to_a
  end

  test "an old acknowledgement cannot clear the new context created by a substitution" do
    interaction_rule(blocking: true)
    duplicate_rule(blocking: true)
    review = review_for([ @product_a, @product_b ])

    interaction = DrugSafety::Gate.blocking_findings(review).first
    DrugSafety::Acknowledge.new(finding: interaction, actor: @pharmacist, action: "overridden",
      reason: "تجاوز موثق للسياق الأول").call

    item = review.items.find_by!(original_product: @product_b)
    result = decide(item, "substituted", substitute_product: @twin_of_a)
    assert result.success?, result.errors.join(", ")

    review.reload
    new_findings = DrugSafety::Gate.current_findings(review).to_a
    assert new_findings.any?, "the substitute must be evaluated in its own right"
    assert new_findings.all?(&:open?), "a decision on the old context must not clear the new one"
    assert DrugSafety::Gate.blocked?(review)
  end

  test "an identical clinical context carries a resolution forward without re-prompting" do
    interaction_rule(blocking: true)
    review = review_for([ @product_a, @product_b ])
    finding = DrugSafety::Gate.blocking_findings(review).first
    DrugSafety::Acknowledge.new(finding:, actor: @pharmacist, action: "acknowledged", reason: "إقرار موثق").call

    PatientProfiles::Save.new(user: @customer, actor: @pharmacist,
      attributes: { date_of_birth: Date.current - 40.years }).call

    review.reload
    carried = DrugSafety::Gate.current_findings(review).first
    assert carried.acknowledged?
    assert_equal finding.id, carried.carried_from_id
    assert_not DrugSafety::Gate.blocked?(review)
  end

  # ---------- online order finalisation ----------

  test "an unresolved blocking finding created by a substitution holds the review open" do
    duplicate_rule(blocking: true)
    review = review_for([ @product_a, @product_b ])
    assert decide(review.items.find_by!(original_product: @product_a), "approved").success?

    item = review.items.find_by!(original_product: @product_b)
    assert decide(item, "substituted", substitute_product: @twin_of_a).success?

    review.reload
    assert review.all_items_decided?
    assert DrugSafety::Gate.blocked?(review)
    assert_not review.completed?, "finalisation must wait for the blocking finding"

    finding = DrugSafety::Gate.blocking_findings(review).first
    assert DrugSafety::Acknowledge.new(finding:, actor: @pharmacist, action: "overridden",
      reason: "قرار سريري موثق").call.success?
    assert review.reload.completed?
  end

  # ---------- POS ----------

  test "POS completion is blocked until a pharmacist resolves the finding and stays idempotent" do
    interaction_rule(blocking: true)
    session = Pos::OpenSession.new(actor: @pharmacist, opening_cash_cents: 10_000).call.record
    sale = session.pos_sales.create!(cashier: @pharmacist, number: "TEST-POS-#{SecureRandom.hex(3)}")
    [ @product_a, @product_b ].each do |product|
      assert Pos::Cart.new(sale:, actor: @pharmacist).add(product:).success?
    end
    review = sale.reload.prescription_review
    assert review, "a POS review must exist for prescription lines"

    review.items.each do |item|
      finding = DrugSafety::Gate.blocking_findings(review).first
      DrugSafety::Acknowledge.new(finding:, actor: @pharmacist, action: "overridden", reason: "تجاوز موثق").call if finding
      assert decide(item.reload, "approved").success?
    end

    DrugSafety::Reevaluate.call(review.reload, trigger: :manual, actor: @pharmacist)
    remaining = DrugSafety::Gate.blocking_findings(review.reload)
    remaining.each do |finding|
      DrugSafety::Acknowledge.new(finding:, actor: @pharmacist, action: "overridden", reason: "تجاوز موثق").call
    end

    sale.reload
    key = "test-pos-#{sale.id}"
    first = Pos::Complete.new(sale:, actor: @pharmacist, idempotency_key: key,
      payments: [ { payment_method: "cash", amount_cents: sale.total_cents, tendered_cents: sale.total_cents } ]).call
    assert first.success?, first.errors.join(", ")

    movements = InventoryMovement.where(reference_type: "PosSaleItem").count
    retry_result = Pos::Complete.new(sale: sale.reload, actor: @pharmacist, idempotency_key: key,
      payments: [ { payment_method: "cash", amount_cents: sale.total_cents, tendered_cents: sale.total_cents } ]).call
    assert retry_result.success?
    assert_equal movements, InventoryMovement.where(reference_type: "PosSaleItem").count
    assert_equal 1, sale.reload.payments.count
  end

  test "POS completion refuses while a blocking finding is unresolved" do
    interaction_rule(blocking: true)
    session = Pos::OpenSession.new(actor: @pharmacist, opening_cash_cents: 10_000).call.record
    sale = session.pos_sales.create!(cashier: @pharmacist, number: "TEST-POS-#{SecureRandom.hex(3)}")
    [ @product_a, @product_b ].each { |product| Pos::Cart.new(sale:, actor: @pharmacist).add(product:) }

    result = Pos::Complete.new(sale: sale.reload, actor: @pharmacist, idempotency_key: "blocked-#{sale.id}",
      payments: [ { payment_method: "cash", amount_cents: sale.total_cents, tendered_cents: sale.total_cents } ]).call
    assert_not result.success?
    assert_includes result.errors.join, "تنبيهات سلامة حرجة"
    assert sale.reload.draft?
  end

  test "ordinary over-the-counter sales are untouched by the safety engine" do
    interaction_rule(blocking: true)
    otc = products(:featured)
    otc.update!(requires_prescription: false)
    session = Pos::OpenSession.new(actor: @pharmacist, opening_cash_cents: 10_000).call.record
    sale = session.pos_sales.create!(cashier: @pharmacist, number: "TEST-OTC-#{SecureRandom.hex(3)}")
    assert Pos::Cart.new(sale:, actor: @pharmacist).add(product: otc).success?

    assert_nil sale.reload.prescription_review
    result = Pos::Complete.new(sale:, actor: @pharmacist, idempotency_key: "otc-#{sale.id}",
      payments: [ { payment_method: "cash", amount_cents: sale.total_cents, tendered_cents: sale.total_cents } ]).call
    assert result.success?, result.errors.join(", ")
    assert sale.reload.completed?
  end

  # ---------- audit ----------

  test "evaluations, acknowledgements and overrides are audited" do
    interaction_rule(blocking: true)
    review = review_for([ @product_a, @product_b ])
    finding = DrugSafety::Gate.blocking_findings(review).first
    DrugSafety::Acknowledge.new(finding:, actor: @pharmacist, action: "overridden", reason: "تجاوز موثق").call

    # Evaluations are their own immutable audit record; staff-triggered ones also raise an admin event.
    assert review.safety_evaluations.exists?
    assert_equal "context_built", review.safety_evaluations.first.trigger
    assert AdminAuditEvent.exists?(action: "drug_safety_finding_overridden", auditable: review)

    PatientProfiles::Save.new(user: @customer, actor: @pharmacist,
      attributes: { date_of_birth: Date.current - 40.years }).call
    assert AdminAuditEvent.exists?(action: "drug_safety_evaluated", auditable: review)
    event = AdminAuditEvent.find_by(action: "drug_safety_finding_overridden", auditable: review)
    assert_equal @pharmacist, event.actor
    assert_not_includes event.metadata.to_s, "ألفازين"
  end

  private

  def rx_product(reference, ingredients)
    product = Product.create!(name: "منتج #{reference}", slug: "rx-#{reference.downcase}-#{SecureRandom.hex(3)}",
      price: 100, requires_prescription: true, active: true,
      category: categories(:medicines), brand: brands(:eva))
    ingredients.each { |item| product.product_active_ingredients.create!(active_ingredient: item) }
    product.inventory_batches.create!(batch_number: "B-#{reference}-#{SecureRandom.hex(2)}", lot_number: "L-#{reference}",
      expiry_date: 1.year.from_now, received_at: Time.current, original_quantity: 20, on_hand_quantity: 20,
      reserved_quantity: 0, unit_cost_cents: 3000)
    Inventory::BatchAggregate.sync_product!(product)
    product
  end

  def build_rule(code:, rule_type:, severity:, blocking:)
    DrugSafetyRule.new(code:, version: 1, name: code, arabic_label: "قاعدة #{code}",
      description: "قاعدة تجريبية معدّة محليًا.", rule_type:, severity:, blocking:, created_by: @admin)
  end

  def interaction_rule(blocking:, severity: :critical)
    rule = build_rule(code: "INT-AB", rule_type: :drug_interaction, severity:, blocking:)
    rule.conditions.build(role: :primary, condition_type: :active_ingredient, active_ingredient: @alpha)
    rule.conditions.build(role: :secondary, condition_type: :active_ingredient, active_ingredient: @beta)
    activate!(rule)
  end

  def duplicate_rule(blocking:)
    activate!(build_rule(code: "DUP-1", rule_type: :duplicate_therapy, severity: :major, blocking:))
  end

  def activate!(rule)
    rule.save!
    result = DrugSafety::RuleLifecycle.activate(rule:, actor: @admin)
    assert result.success?, result.errors.join(", ")
    rule.reload
  end

  def decide(item, decision, substitute_product: nil)
    Prescriptions::DecideLine.new(item:, actor: @pharmacist, decision:,
      reason: "قرار سريري موثق للاختبار", substitute_product:).call
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
