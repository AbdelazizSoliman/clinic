module Orders
  class CreateFromCart
    Result = Data.define(:success?, :order, :errors, :cart_changed?, :prescription_required?)
    OPERATIONAL_PAYMENT_METHOD = "cash_on_delivery"
    DELIVERY_METHODS = Order.delivery_methods.keys.freeze

    def initialize(user:, cart:, address_id:, delivery_method:, payment_method:, submission_token:, delivery_slot_id: nil, prescription_files: [], prescription_notes: nil, delivery_notes: nil)
      @user = user
      @cart = cart
      @address_id = address_id
      @delivery_method = delivery_method
      @payment_method = payment_method
      @submission_token = submission_token
      @prescription_files = Array(prescription_files).compact_blank
      @prescription_notes = prescription_notes
      @delivery_notes = delivery_notes
      @delivery_slot_id = delivery_slot_id
    end

    def call
      existing = existing_order
      return success(existing) if existing

      errors = preflight_errors
      return failure(errors) if errors.any?

      order = nil
      transaction_errors = []
      ActiveRecord::Base.transaction do
        @cart.lock!
        unless @cart.active? && ActiveSupport::SecurityUtils.secure_compare(@cart.checkout_submission_token.to_s, @submission_token.to_s)
          transaction_errors << "جلسة الإرسال غير صالحة أو استُخدمت من قبل"
          raise ActiveRecord::Rollback
        end

        @cart.update!(status: :converting)
        items = @cart.items.includes(product: %i[brand category]).to_a
        products = Product.where(id: items.map(&:product_id)).order(:id).lock.index_by(&:id)
        transaction_errors.concat(validate_locked_items(items, products))
        if transaction_errors.any?
          raise ActiveRecord::Rollback
        end

        lock_delivery_slot!(transaction_errors)
        raise ActiveRecord::Rollback if transaction_errors.any?
        lock_promotions!
        totals = Checkout::Totals.call(items, zone: @delivery_zone, delivery_method: @delivery_method_record,
          user: @user, coupon: @cart.applied_coupon)
        if @cart.applied_coupon && totals.applied_promotions.none? { |applied| applied.coupon&.id == @cart.applied_coupon_id }
          transaction_errors << "كود الخصم لم يعد صالحًا لهذه السلة"
          raise ActiveRecord::Rollback
        end
        prescription_required = totals.lines.any? { |line| line.product.requires_prescription? }
        if prescription_required
          transaction_errors.concat(Prescriptions::AttachmentValidator.call(@prescription_files))
          raise ActiveRecord::Rollback if transaction_errors.any?
        end

        order = create_order!(totals, prescription_required)
        order.events.create!(event_type: "order_submitted", to_status: order.status, customer_visible: true)
        create_items_and_reservations!(order, totals)
        create_commercial_records!(order, totals)
        create_address_snapshot!(order)
        order.create_fulfilment!(delivery_zone: @delivery_zone, delivery_slot: @delivery_slot, status: :unassigned)
        create_prescription!(order) if prescription_required
        @cart.update!(status: :completed)
      end

      return failure(transaction_errors, cart_changed: transaction_errors.any?) unless order&.persisted?

      success(order)
    rescue ActiveRecord::RecordNotUnique
      existing = existing_order
      existing ? success(existing) : failure([ "تعذر إنشاء الطلب؛ حاول مرة أخرى" ])
    rescue ActiveRecord::RecordInvalid => error
      failure(error.record.errors.full_messages.presence || [ "تعذر إنشاء الطلب" ])
    end

    private

    def existing_order
      return unless @user && @submission_token.present?

      @user.orders.joins(:cart).find_by(carts: { checkout_submission_token: @submission_token })
    end

    def preflight_errors
      errors = []
      errors << "يجب تسجيل الدخول" unless @user
      errors << "لا توجد سلة نشطة" unless @cart && @cart.user_id == @user&.id
      errors << "اختر طريقة توصيل صحيحة" unless DELIVERY_METHODS.include?(@delivery_method)
      errors << "الدفع عند الاستلام هو الطريقة التشغيلية الوحيدة حاليًا" unless @payment_method == OPERATIONAL_PAYMENT_METHOD
      errors << "رمز إرسال الطلب غير صحيح" if @submission_token.blank? || @cart&.checkout_submission_token != @submission_token
      @address = @user&.addresses&.where(active: true)&.find_by(id: @address_id)
      errors << "اختر عنوانًا نشطًا تابعًا لحسابك" unless @address
      match = Delivery::ZoneMatcher.call(@address) if @address
      @delivery_zone = match&.zone
      errors << (match&.error || "العنوان خارج نطاق التوصيل الحالي") if @address && !match&.matched?
      @delivery_method_record = @delivery_zone&.delivery_methods&.active&.find_by(code: @delivery_method)
      errors << "طريقة التوصيل غير متاحة في المنطقة المحددة" if @delivery_zone && !@delivery_method_record
      @delivery_slot = @delivery_zone&.delivery_slots&.find_by(id: @delivery_slot_id) if @delivery_method == "scheduled"
      errors << "اختر موعد توصيل متاحًا" if @delivery_method == "scheduled" && !@delivery_slot&.available?
      errors << "الطلب أقل من الحد الأدنى لمنطقة التوصيل" if @delivery_zone&.minimum_order_cents && @cart && @cart.subtotal_cents < @delivery_zone.minimum_order_cents
      errors
    end

    def validate_locked_items(items, products)
      return [ "السلة فارغة" ] if items.empty?

      items.filter_map do |item|
        product = products[item.product_id]
        if !product&.active?
          "#{item.product.name} لم يعد نشطًا"
        elsif item.quantity > product.available_to_sell_quantity
          "الكمية المطلوبة من #{product.name} غير متاحة؛ المتاح #{product.available_to_sell_quantity}"
        end
      end
    end

    def create_order!(totals, prescription_required)
      @user.orders.create!(
        cart: @cart, number: Orders::NumberGenerator.call,
        status: prescription_required ? :pending_prescription : :submitted,
        payment_method: @payment_method, payment_status: :unpaid, delivery_method: @delivery_method,
        currency: @cart.currency, subtotal_cents: totals.subtotal_cents, discount_cents: totals.discount_cents,
        product_discount_cents: totals.product_discount_cents, cart_discount_cents: totals.cart_discount_cents,
        delivery_discount_cents: totals.delivery_discount_cents, pricing_calculation_version: totals.calculation_version,
        delivery_fee_cents: totals.delivery_fee_cents, total_cents: totals.total_cents,
        delivery_zone: @delivery_zone, delivery_slot: @delivery_slot, delivery_zone_code: @delivery_zone.code,
        delivery_zone_name: @delivery_zone.name, delivery_method_name: @delivery_method_record.name,
        delivery_estimated_min_minutes: @delivery_zone.estimated_min_minutes,
        delivery_estimated_max_minutes: @delivery_zone.estimated_max_minutes,
        scheduled_for: @delivery_slot&.scheduled_at,
        customer_email: @user.email, customer_mobile_number: @user.mobile_number,
        customer_first_name: @user.first_name, customer_last_name: @user.last_name,
        delivery_notes: @delivery_notes.to_s.squish.presence, prescription_required:, submitted_at: Time.current
      )
    end

    def create_items_and_reservations!(order, totals)
      totals.lines.each do |line|
        product = line.product
        item = order.items.create!(
          product:, product_name: product.name, product_slug: product.slug,
          brand_name: product.brand.name, category_name: product.category.name,
          unit_price_cents: line.final_unit_price_cents, original_unit_price_cents: line.original_unit_price_cents,
          final_unit_price_cents: line.final_unit_price_cents, compare_at_price_cents: line.compare_at_price_cents,
          discount_cents: line.discount_cents, quantity: line.quantity,
          line_total_cents: line.line_total_cents, requires_prescription: product.requires_prescription?
        )
        order.inventory_reservations.create!(order_item: item, product:, quantity: line.quantity, status: :active,
          expires_at: Inventory::ReservationExpiryPolicy.expires_at_for(order))
      end
    end

    def lock_promotions!
      ids = Promotion.effective_at.automatic.ids
      ids << @cart.applied_coupon.promotion_id if @cart.applied_coupon
      Promotion.where(id: ids.uniq.sort).order(:id).lock.load
      @cart.applied_coupon&.lock!
    end

    def create_commercial_records!(order, totals)
      totals.applied_promotions.each do |applied|
        promotion = applied.promotion
        order.order_promotions.create!(promotion:, coupon: applied.coupon, promotion_name: promotion.name,
          code: applied.coupon&.code, promotion_type: promotion.promotion_type, discount_type: promotion.discount_type,
          discount_value_snapshot: promotion.discount_value, discount_cents: applied.discount_cents,
          metadata: { scope: applied.scope, calculation_version: totals.calculation_version })
        order.promotion_redemptions.create!(promotion:, coupon: applied.coupon, user: @user,
          code_snapshot: applied.coupon&.code, discount_cents: applied.discount_cents,
          status: :redeemed, redeemed_at: Time.current)
      end
    end

    def create_address_snapshot!(order)
      fields = %i[label recipient_name mobile_number governorate city district street building_number floor apartment landmark postal_code delivery_notes latitude longitude]
      order.create_order_address!(@address.attributes.symbolize_keys.slice(*fields))
    end

    def lock_delivery_slot!(errors)
      return unless @delivery_method == "scheduled"
      @delivery_slot.lock!
      unless @delivery_slot.available? && @delivery_slot.delivery_zone_id == @delivery_zone.id
        errors << "موعد التوصيل لم يعد متاحًا"
        return
      end
      @delivery_slot.update!(booked_count: @delivery_slot.booked_count + 1)
    end

    def create_prescription!(order)
      prescription = order.build_prescription(user: @user, status: :submitted, submitted_at: Time.current, customer_notes: @prescription_notes.to_s.squish.presence)
      prescription.images.attach(@prescription_files)
      prescription.save!
    end

    def success(order)
      Result.new(success?: true, order:, errors: [], cart_changed?: false, prescription_required?: order.prescription_required?)
    end

    def failure(errors, cart_changed: false)
      Result.new(success?: false, order: nil, errors: Array(errors), cart_changed?: cart_changed, prescription_required?: false)
    end
  end
end
