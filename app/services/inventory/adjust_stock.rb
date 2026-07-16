module Inventory
  class AdjustStock
    Result = Data.define(:success?, :product, :movement, :errors)
    TYPES = %w[manual_increase manual_decrease correction damaged expired system_adjustment].freeze

    def initialize(product:, actor:, movement_type:, quantity_delta:, reason:, lock_version: nil)
      @product, @actor, @movement_type, @reason, @lock_version = product, actor, movement_type.to_s, reason, lock_version
      @quantity_delta = Integer(quantity_delta, exception: false)
    end

    def call
      return failure("غير مصرح بإدارة المخزون") unless @actor&.can_manage_inventory?
      return failure("نوع الحركة غير مسموح") unless TYPES.include?(@movement_type)
      return failure("الكمية يجب ألا تساوي صفرًا") unless @quantity_delta&.nonzero?
      return failure("سبب الحركة مطلوب") if @reason.blank?

      movement = nil
      Product.transaction do
        @product.lock!
        raise ActiveRecord::StaleObjectError.new(@product, "stock") if @lock_version && @product.lock_version != @lock_version.to_i
        before = @product.stock_quantity
        after = before + @quantity_delta
        reserved = @product.active_reserved_quantity
        return failure("لا يمكن خفض المخزون عن الكمية المحجوزة #{reserved}") if after < reserved
        return failure("لا يمكن أن يصبح المخزون سالبًا") if after.negative?

        was_low = before - reserved <= @product.low_stock_threshold
        @product.update!(stock_quantity: after)
        movement = @product.inventory_movements.create!(actor: @actor, movement_type: @movement_type,
          quantity_delta: @quantity_delta, quantity_before: before, quantity_after: after, reason: @reason.to_s.squish)
        notify_low_stock(after - reserved) unless was_low
      end
      Result.new(success?: true, product: @product, movement:, errors: [])
    rescue ActiveRecord::StaleObjectError
      failure("تم تحديث المخزون بواسطة مستخدم آخر؛ أعد تحميل الصفحة")
    end

    private

    def notify_low_stock(available)
      return if available > @product.low_stock_threshold
      User.where(active: true, role: %i[inventory_manager admin]).find_each do |recipient|
        kind = available <= 0 ? "product_out_of_stock" : "product_low_stock"
        Notifications::Create.call(user: recipient, actor: @actor, notifiable: @product, kind:,
          title: available <= 0 ? "نفد مخزون منتج" : "مخزون منخفض", body: @product.name,
          key: "#{kind}-#{@product.id}-#{@product.lock_version}")
      end
    end
    def failure(message) = Result.new(success?: false, product: @product, movement: nil, errors: [ message ])
  end
end
