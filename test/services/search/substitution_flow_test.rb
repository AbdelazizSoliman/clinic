require "test_helper"

# Search only helps the pharmacist FIND a candidate. Everything after selection — the
# clinical decision and the Phase 20 re-evaluation — must behave exactly as before.
class Search::SubstitutionFlowTest < ActiveSupport::TestCase
  setup do
    @admin = users(:admin)
    @pharmacist = users(:pharmacist)
    @customer = users(:customer)
    @alpha = ActiveIngredient.create!(code: "ALFA", name: "ألفازين")
    @beta = ActiveIngredient.create!(code: "BETA", name: "بيتازول")
    @original = rx_product("دواء أصلي للبحث", [ @alpha ])
    @substitute = rx_product("دواء بديل للبحث", [ @beta ])
  end

  test "a product found through search still passes through the full clinical pipeline" do
    found = Search::Products.call(query: "دواء بديل", context: :substitution).records
    assert_includes found, @substitute

    review = review_for([ @original ])
    item = review.items.sole
    result = Prescriptions::DecideLine.new(item:, actor: @pharmacist, decision: "substituted",
      reason: "بديل اختير بعد البحث", substitute_product: found.first).call

    assert result.success?, result.errors.join(", ")
    item.reload
    assert item.substituted?
    assert_equal @substitute, item.dispensed_product
    assert item.therapeutic_substitution.present?
    assert_operator review.reload.safety_evaluations.count, :>=, 2,
      "the substitution must still trigger a fresh safety evaluation"
  end

  test "search cannot bypass the safety gate on the product it surfaced" do
    rule = DrugSafetyRule.new(code: "INT-SEARCH", version: 1, name: "interaction", arabic_label: "تداخل تجريبي",
      description: "قاعدة تجريبية.", rule_type: :drug_interaction, severity: :critical, blocking: true,
      created_by: @admin)
    rule.conditions.build(role: :primary, condition_type: :active_ingredient, active_ingredient: @alpha)
    rule.conditions.build(role: :secondary, condition_type: :active_ingredient, active_ingredient: @beta)
    rule.save!
    DrugSafety::RuleLifecycle.activate(rule:, actor: @admin)

    review = review_for([ @original, @substitute ])
    assert DrugSafety::Gate.blocked?(review), "the engine still owns the clinical gate"

    item = review.items.order(:id).first
    blocked = Prescriptions::DecideLine.new(item:, actor: @pharmacist, decision: "approved",
      reason: "محاولة بعد البحث").call
    assert_not blocked.success?
    assert_includes blocked.errors.join, "تنبيهات سلامة"
  end

  test "search cannot surface a product whose only stock is unusable" do
    expired = rx_product("دواء منتهي للبحث", [ @beta ], expiry: Date.yesterday)
    assert_not_includes Search::Products.call(query: "دواء", context: :substitution).records, expired

    review = review_for([ @original ])
    result = Prescriptions::DecideLine.new(item: review.items.sole, actor: @pharmacist, decision: "substituted",
      reason: "محاولة استبدال بمنتج غير متاح", substitute_product: expired).call
    assert_not result.success?, "the Phase 19 availability guard is unchanged"
  end

  private

  def rx_product(name, ingredients, expiry: 1.year.from_now)
    record = Product.create!(name:, slug: "sf-#{SecureRandom.hex(4)}", price: 90, stock_quantity: 10,
      category: categories(:medicines), brand: brands(:eva), requires_prescription: true, active: true,
      sku: "SF-#{SecureRandom.hex(3).upcase}")
    ingredients.each { |ingredient| record.product_active_ingredients.create!(active_ingredient: ingredient) }
    record.inventory_batches.create!(batch_number: "B-#{SecureRandom.hex(3)}", lot_number: "L-#{SecureRandom.hex(3)}",
      expiry_date: expiry, received_at: Time.current, original_quantity: 10, on_hand_quantity: 10,
      reserved_quantity: 0, unit_cost_cents: 2000)
    Inventory::BatchAggregate.sync_product!(record)
    record
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
