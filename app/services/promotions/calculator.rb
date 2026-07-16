module Promotions
  class Calculator
    Applied = Data.define(:promotion, :coupon, :discount_cents, :scope)
    Line = Data.define(:product, :quantity, :unit_price_cents, :original_unit_price_cents, :final_unit_price_cents, :compare_at_price_cents, :discount_cents, :line_total_cents)
    Result = Data.define(:lines, :subtotal_cents, :product_discount_cents, :cart_discount_cents,
      :delivery_discount_cents, :discount_cents, :delivery_fee_cents, :total_cents, :applied_promotions,
      :rejected_promotions, :calculation_version)
    VERSION = "promotions-v1"

    def self.call(items:, user: nil, coupon: nil, zone: nil, delivery_method: nil, now: Time.current, include_automatic: true)
      new(items:, user:, coupon:, zone:, delivery_method:, now:, include_automatic:).call
    end

    def initialize(items:, user:, coupon:, zone:, delivery_method:, now:, include_automatic: true)
      @items, @user, @coupon, @zone, @delivery_method, @now = Array(items), user, coupon, zone, delivery_method, now
      @include_automatic = include_automatic
    end

    def call
      subtotal = @items.sum { |item| cents(item.product.price) * item.quantity }
      automatic = @include_automatic ? Promotion.effective_at(@now).automatic.includes(:products, :categories, :brands, :excluded_products).to_a : []
      eligible = automatic.filter_map { |promotion| eligibility(promotion, subtotal) }
      coupon_result = eligibility(@coupon.promotion, subtotal, @coupon) if @coupon
      coupon_result = nil unless coupon_result&.eligible?
      if coupon_result && eligible.any? && (!coupon_result.promotion.stackable? || eligible.any? { |result| !result.promotion.stackable? })
        automatic_only = self.class.call(items: @items, user: @user, zone: @zone, delivery_method: @delivery_method, now: @now)
        coupon_only = self.class.call(items: @items, user: @user, coupon: @coupon, zone: @zone,
          delivery_method: @delivery_method, now: @now, include_automatic: false)
        return [ automatic_only, coupon_only ].max_by do |result|
          best = result.applied_promotions.max_by { |entry| [ entry.promotion.priority, -entry.promotion.id ] }
          [ result.discount_cents, best&.promotion&.priority.to_i, -(best&.promotion&.id || 0) ]
        end
      end
      lines, line_applied = calculate_lines(eligible, coupon_result)
      product_discount = lines.sum(&:discount_cents)
      remaining = subtotal - product_discount
      cart_applied = best_cart_discount(eligible, coupon_result, remaining)
      cart_discount = cart_applied&.discount_cents.to_i
      fee = @zone ? @zone.fee_for(subtotal, method: @delivery_method&.additional_fee_cents) : 0
      delivery_applied = best_delivery_discount(eligible, coupon_result, fee)
      delivery_discount = delivery_applied&.discount_cents.to_i
      applied = (line_applied + [ cart_applied, delivery_applied ]).compact
        .group_by { |entry| [ entry.promotion, entry.coupon, entry.scope ] }
        .map { |(promotion, coupon, scope), entries| Applied.new(promotion:, coupon:, scope:, discount_cents: entries.sum(&:discount_cents)) }
      discount = product_discount + cart_discount + delivery_discount
      Result.new(lines:, subtotal_cents: subtotal, product_discount_cents: product_discount,
        cart_discount_cents: cart_discount, delivery_discount_cents: delivery_discount,
        discount_cents: discount, delivery_fee_cents: fee, total_cents: [ subtotal - product_discount - cart_discount + fee - delivery_discount, 0 ].max,
        applied_promotions: applied, rejected_promotions: [], calculation_version: VERSION)
    end

    private

    def eligibility(promotion, subtotal, coupon = nil)
      Promotions::Eligibility.new(promotion:, coupon:, items: @items, user: @user, subtotal_cents: subtotal,
        zone: @zone, delivery_method: @delivery_method, now: @now).call
    end

    def calculate_lines(automatic, coupon_result)
      applied = []
      lines = @items.map do |item|
        original = cents(item.product.price)
        base = original * item.quantity
        candidates = automatic.select { |result| %w[product category brand].include?(result.promotion.promotion_type) && result.eligible_items.include?(item) }
        candidates << coupon_result if coupon_result && %w[product category brand].include?(coupon_result.promotion.promotion_type) && coupon_result.eligible_items.include?(item)
        choices = candidates.map { |result| [ discount_for(result.promotion, base, original, result.coupon), result ] }
        amount, winner = choices.max_by { |value, result| [ value, result.promotion.priority, -result.promotion.id ] }
        amount ||= 0
        amount = [ amount, base ].min
        applied << Applied.new(promotion: winner.promotion, coupon: winner.coupon, discount_cents: amount, scope: "line") if winner && amount.positive?
        final_total = base - amount
        final_unit = final_total / item.quantity
        compare = cents(item.product.compare_at_price) if item.product.compare_at_price
        Line.new(product: item.product, quantity: item.quantity, unit_price_cents: final_unit, original_unit_price_cents: original,
          final_unit_price_cents: final_unit, compare_at_price_cents: compare, discount_cents: amount, line_total_cents: final_total)
      end
      [ lines, applied ]
    end

    def best_cart_discount(automatic, coupon_result, remaining)
      candidates = automatic.select { |result| result.promotion.promotion_type == "cart" }
      candidates << coupon_result if coupon_result&.promotion&.promotion_type == "cart"
      best_applied(candidates, remaining, "cart")
    end

    def best_delivery_discount(automatic, coupon_result, fee)
      candidates = automatic.select { |result| result.promotion.promotion_type == "delivery" }
      candidates << coupon_result if coupon_result&.promotion&.promotion_type == "delivery"
      best_applied(candidates, fee, "delivery")
    end

    def best_applied(candidates, base, scope)
      amount, winner = candidates.map { |result| [ discount_for(result.promotion, base, base, result.coupon), result ] }
        .max_by { |value, result| [ value, result.promotion.priority, -result.promotion.id ] }
      return unless winner && amount.positive?
      Applied.new(promotion: winner.promotion, coupon: winner.coupon, discount_cents: [ amount, base ].min, scope:)
    end

    def discount_for(promotion, base, unit, coupon)
      value = case promotion.discount_type
      when "percentage" then (base * promotion.discount_value / 100.0).round
      when "fixed_amount" then promotion.discount_value
      when "fixed_price" then [ base - promotion.discount_value * (base / unit), 0 ].max
      when "free_delivery" then base
      else 0
      end
      cap = [ promotion.maximum_discount_cents, coupon&.maximum_discount_cents ].compact.min
      cap ? [ value, cap ].min : value
    end

    def cents(value) = (value * 100).round
  end
end
