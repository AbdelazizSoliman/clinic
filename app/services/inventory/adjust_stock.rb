module Inventory
  class AdjustStock
    Result = Data.define(:success?, :product, :movement, :errors)
    TYPES = %w[manual_increase manual_decrease correction damaged expired system_adjustment batch_loss supplier_replacement].freeze

    def initialize(product:, actor:, movement_type:, quantity_delta:, reason:, lock_version: nil)
      @product, @actor, @movement_type, @reason, @lock_version = product, actor, movement_type.to_s, reason, lock_version
      @quantity_delta = Integer(quantity_delta, exception: false)
    end

    def call
      return failure("غير مصرح بإدارة المخزون") unless @actor&.can_manage_inventory?
      return failure("نوع الحركة غير مسموح") unless TYPES.include?(@movement_type)
      return failure("الكمية يجب ألا تساوي صفرًا") unless @quantity_delta&.nonzero?
      return failure("سبب الحركة مطلوب") if @reason.blank?
      return failure("تم تحديث المخزون بواسطة مستخدم آخر؛ أعد تحميل الصفحة") if @lock_version && @product.lock_version != @lock_version.to_i

      batch = @product.inventory_batches.not_quarantined.unexpired.fefo
        .find { |candidate| @quantity_delta.positive? || candidate.available_quantity >= -@quantity_delta }
      return failure("لا توجد تشغيلة صالحة خارج الكمية المحجوزة وبها رصيد كافٍ") unless batch
      before_available = @product.available_to_sell_quantity
      result = Inventory::AdjustBatch.new(batch:, actor: @actor, movement_type: @movement_type,
        quantity_delta: @quantity_delta, reason: @reason).call
      return failure(result.errors.join("، ")) unless result.success?
      notify_low_stock(@product.reload.available_to_sell_quantity) if before_available > @product.low_stock_threshold
      Result.new(success?: true, product: @product, movement: result.movement, errors: [])
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
