module Products
  class UpdatePricing
    Result = Data.define(:success?, :product, :price_change, :errors)

    def initialize(product:, actor:, price:, compare_at_price: nil, cost_price: nil, reason:, source: :admin, lock_version: nil)
      @product, @actor, @reason, @source, @lock_version = product, actor, reason, source, lock_version
      @price, @compare_at_price, @cost_price = decimal(price), decimal(compare_at_price), decimal(cost_price)
    end

    def call
      return failure("غير مصرح بإدارة الأسعار") unless @actor&.can_manage_catalog?
      return failure("سبب تغيير السعر مطلوب") if @reason.blank?
      return failure("السعر غير صحيح") unless @price && @price >= 0
      return failure("سعر المقارنة يجب أن يتجاوز السعر الحالي") if @compare_at_price && @compare_at_price <= @price
      return failure("سعر التكلفة غير صحيح") if @cost_price&.negative?

      change = nil
      Product.transaction do
        @product.lock!
        raise ActiveRecord::StaleObjectError.new(@product, "pricing") if @lock_version && @product.lock_version != @lock_version.to_i
        old = money_snapshot(@product)
        @product.update!(price: @price, compare_at_price: @compare_at_price, cost_price: @cost_price)
        change = @product.price_changes.create!(changed_by: @actor, source: @source, reason: @reason.to_s.squish,
          effective_at: Time.current, **old, new_price_cents: cents(@price),
          new_compare_at_price_cents: cents(@compare_at_price), new_cost_price_cents: cents(@cost_price))
      end
      Result.new(success?: true, product: @product, price_change: change, errors: [])
    rescue ActiveRecord::StaleObjectError
      failure("تم تحديث المنتج بواسطة مستخدم آخر؛ أعد تحميل الصفحة")
    rescue ActiveRecord::RecordInvalid => error
      failure(error.record.errors.full_messages.join("، "))
    end

    private

    def decimal(value) = value.present? ? BigDecimal(value.to_s) : nil
    def cents(value) = value ? (value * 100).round : nil
    def money_snapshot(product)
      { old_price_cents: cents(product.price), old_compare_at_price_cents: cents(product.compare_at_price), old_cost_price_cents: cents(product.cost_price) }
    end
    def failure(message) = Result.new(success?: false, product: @product, price_change: nil, errors: [ message ])
  rescue ArgumentError
    failure("صيغة السعر غير صحيحة")
  end
end
