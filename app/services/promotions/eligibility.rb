module Promotions
  class Eligibility
    Result = Data.define(:eligible?, :promotion, :coupon, :eligible_items, :rejection_code)

    def initialize(promotion:, items:, user: nil, coupon: nil, subtotal_cents: nil, zone: nil, delivery_method: nil, now: Time.current)
      @promotion, @items, @user, @coupon = promotion, Array(items), user, coupon
      @subtotal_cents = subtotal_cents || @items.sum { |item| unit_cents(item) * item.quantity }
      @zone, @delivery_method, @now = zone, delivery_method, now
    end

    def call
      return reject(:inactive) unless @promotion.effective?(@now)
      return reject(:invalid_coupon) if @coupon && (!@coupon.effective?(@now) || @coupon.promotion_id != @promotion.id)
      return reject(:authentication_required) if authenticated_only? && !@user
      return reject(:first_order_only) if first_order_only? && !first_order?
      return reject(:minimum_subtotal) if @subtotal_cents < minimum_subtotal
      return reject(:usage_limit) if usage_exhausted?
      return reject(:delivery_restriction) unless delivery_matches?
      eligible = @items.select { |item| eligible_product?(item.product) }
      return reject(:no_eligible_items) if @promotion.promotion_type != "cart" && @promotion.promotion_type != "delivery" && eligible.empty?
      Result.new(eligible?: true, promotion: @promotion, coupon: @coupon, eligible_items: eligible, rejection_code: nil)
    end

    private

    def reject(code) = Result.new(eligible?: false, promotion: @promotion, coupon: @coupon, eligible_items: [], rejection_code: code)
    def authenticated_only? = @coupon&.authenticated_only.nil? ? @promotion.authenticated_only? : @coupon.authenticated_only?
    def first_order_only? = @coupon&.first_order_only.nil? ? @promotion.first_order_only? : @coupon.first_order_only?
    def minimum_subtotal = [ @promotion.minimum_subtotal_cents, @coupon&.minimum_subtotal_cents.to_i ].max
    def first_order? = @user && !@user.orders.where.not(status: %i[cancelled rejected]).exists?
    def unit_cents(item) = (item.product.price * 100).round

    def usage_exhausted?
      active = @promotion.redemptions.redeemed
      total_limit = [ @promotion.total_usage_limit, @coupon&.total_usage_limit ].compact.min
      customer_limit = [ @promotion.per_customer_usage_limit, @coupon&.per_customer_usage_limit ].compact.min
      (total_limit && active.count >= total_limit) || (customer_limit && @user && active.where(user: @user).count >= customer_limit)
    end

    def delivery_matches?
      return true unless @promotion.promotion_type == "delivery"
      (!@promotion.delivery_zone_id || @promotion.delivery_zone_id == @zone&.id) &&
        (@promotion.delivery_method_code.blank? || @promotion.delivery_method_code == @delivery_method&.code)
    end

    def eligible_product?(product)
      return false if @promotion.excluded_product_ids.include?(product.id)
      return false if product.requires_prescription? && !@promotion.applies_to_prescription_products?
      case @promotion.promotion_type
      when "product" then @promotion.product_ids.include?(product.id)
      when "category" then @promotion.category_ids.include?(product.category_id)
      when "brand" then @promotion.brand_ids.include?(product.brand_id)
      when "cart", "delivery" then true
      else false
      end
    end
  end
end
