module Orders
  class CreateFromCart
    Result = Data.define(:success?, :order, :errors, :cart_changed?, :prescription_required?)
    OPERATIONAL_PAYMENT_METHOD = "cash_on_delivery"
    DELIVERY_METHODS = Order.delivery_methods.keys.freeze

    def initialize(user:, cart:, address_id:, delivery_method:, payment_method:, submission_token:, prescription_files: [], prescription_notes: nil, delivery_notes: nil)
      @user = user
      @cart = cart
      @address_id = address_id
      @delivery_method = delivery_method
      @payment_method = payment_method
      @submission_token = submission_token
      @prescription_files = Array(prescription_files).compact_blank
      @prescription_notes = prescription_notes
      @delivery_notes = delivery_notes
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

        totals = Checkout::Totals.call(items)
        prescription_required = totals.lines.any? { |line| line.product.requires_prescription? }
        if prescription_required
          transaction_errors.concat(Prescriptions::AttachmentValidator.call(@prescription_files))
          raise ActiveRecord::Rollback if transaction_errors.any?
        end

        order = create_order!(totals, prescription_required)
        create_items_and_reservations!(order, totals)
        create_address_snapshot!(order)
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
      errors << "العنوان خارج نطاق التوصيل الحالي" if @address && !Checkout::DeliveryAreaPolicy.supported?(@address)
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
        delivery_fee_cents: totals.delivery_fee_cents, total_cents: totals.total_cents,
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
          unit_price_cents: line.unit_price_cents, compare_at_price_cents: line.compare_at_price_cents,
          discount_cents: line.discount_cents, quantity: line.quantity,
          line_total_cents: line.line_total_cents, requires_prescription: product.requires_prescription?
        )
        order.inventory_reservations.create!(order_item: item, product:, quantity: line.quantity, status: :active)
      end
    end

    def create_address_snapshot!(order)
      fields = %i[label recipient_name mobile_number governorate city district street building_number floor apartment landmark postal_code delivery_notes latitude longitude]
      order.create_order_address!(@address.attributes.symbolize_keys.slice(*fields))
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
