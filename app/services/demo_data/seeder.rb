module DemoData
  class Seeder
    class Refused < StandardError; end

    CATEGORY_DATA = [
      [ "demo-pain-fever", "مسكنات وخافضات حرارة", "💊" ], [ "demo-cold-allergy", "نزلات البرد والحساسية", "🤧" ],
      [ "demo-skin-care", "العناية بالبشرة والشمس", "✨" ], [ "demo-hair-care", "العناية بالشعر", "🧴" ],
      [ "demo-mother-baby", "رعاية الأم والطفل", "🍼" ], [ "demo-vitamins", "فيتامينات ومكملات غذائية", "🍊" ],
      [ "demo-first-aid", "الإسعافات الأولية", "🩹" ], [ "demo-prescription", "أدوية بوصفة طبية", "📋" ]
    ].freeze
    BRAND_DATA = [ [ "demo-nile-care", "نايل كير" ], [ "demo-cairo-health", "كايرو هيلث" ],
      [ "demo-lotus", "لوتس للعناية" ], [ "demo-family", "فاميلي كير" ], [ "demo-vita", "فيتا بلس" ] ].freeze
    PRODUCT_DATA = [
      [ "paracetamol-20", "باراسيتامول 500 مجم — 20 قرص", "demo-pain-fever", "demo-nile-care", 42, 60, 4, false, true ],
      [ "pain-relief-gel", "جل موضعي للعناية بالعضلات 50 جم", "demo-pain-fever", "demo-cairo-health", 88, 110, 22, false, false ],
      [ "fever-syrup", "شراب خافض حرارة للأطفال 100 مل", "demo-pain-fever", "demo-family", 55, nil, 18, false, false ],
      [ "cold-tablets", "أقراص لأعراض البرد — 20 قرص", "demo-cold-allergy", "demo-nile-care", 68, 80, 30, false, true ],
      [ "saline-spray", "بخاخ محلول ملحي 30 مل", "demo-cold-allergy", "demo-family", 75, nil, 3, false, false ],
      [ "allergy-tablets", "أقراص حساسية — 10 أقراص", "demo-cold-allergy", "demo-cairo-health", 64, nil, 0, false, false ],
      [ "gentle-cleanser", "غسول لطيف للبشرة 200 مل", "demo-skin-care", "demo-lotus", 245, 290, 14, false, true ],
      [ "daily-moisturizer", "مرطب يومي للبشرة 100 مل", "demo-skin-care", "demo-lotus", 210, nil, 20, false, false ],
      [ "sun-cream", "كريم حماية من الشمس 50 مل", "demo-skin-care", "demo-lotus", 330, 390, 7, false, true ],
      [ "hair-shampoo", "شامبو عناية يومية 400 مل", "demo-hair-care", "demo-lotus", 175, nil, 25, false, false ],
      [ "hair-conditioner", "بلسم عناية يومية 350 مل", "demo-hair-care", "demo-lotus", 165, nil, 2, false, false ],
      [ "hair-serum", "سيروم شعر خفيف 60 مل", "demo-hair-care", "demo-lotus", 230, 270, 0, false, false ],
      [ "baby-wipes", "مناديل أطفال لطيفة — 72 منديل", "demo-mother-baby", "demo-family", 95, nil, 34, false, true ],
      [ "baby-shampoo", "شامبو أطفال لطيف 300 مل", "demo-mother-baby", "demo-family", 145, nil, 15, false, false ],
      [ "baby-cream", "كريم عناية للأطفال 100 جم", "demo-mother-baby", "demo-family", 120, 145, 5, false, false ],
      [ "vitamin-c", "فيتامين ج 500 مجم — 30 قرص", "demo-vitamins", "demo-vita", 185, 220, 28, false, true ],
      [ "vitamin-d", "فيتامين د3 — 30 كبسولة", "demo-vitamins", "demo-vita", 215, nil, 9, false, false ],
      [ "multivitamin", "مكمل متعدد الفيتامينات — 30 قرص", "demo-vitamins", "demo-vita", 260, 310, 17, false, true ],
      [ "zinc-tablets", "زنك — 20 قرص", "demo-vitamins", "demo-vita", 135, nil, 1, false, false ],
      [ "adhesive-bandages", "شرائط جروح متنوعة — 30 قطعة", "demo-first-aid", "demo-cairo-health", 70, nil, 40, false, false ],
      [ "sterile-gauze", "شاش معقم — 10 قطع", "demo-first-aid", "demo-cairo-health", 48, nil, 13, false, false ],
      [ "digital-thermometer", "ترمومتر رقمي منزلي", "demo-first-aid", "demo-family", 190, 225, 6, false, true ],
      [ "antiseptic-solution", "محلول تنظيف موضعي 120 مل", "demo-first-aid", "demo-cairo-health", 62, nil, 24, false, false ],
      [ "rx-tablets-a", "دواء تجريبي أ — 14 قرص", "demo-prescription", "demo-nile-care", 195, nil, 20, true, true ],
      [ "rx-capsules-b", "دواء تجريبي ب — 10 كبسولات", "demo-prescription", "demo-cairo-health", 240, nil, 16, true, false ],
      [ "rx-suspension-c", "معلق تجريبي ج 70 مل", "demo-prescription", "demo-family", 175, nil, 8, true, false ],
      [ "inactive-seasonal", "منتج موسمي غير نشط", "demo-cold-allergy", "demo-nile-care", 90, nil, 12, false, false, false ],
      [ "first-aid-kit", "حقيبة إسعافات أولية منزلية", "demo-first-aid", "demo-family", 420, 480, 10, false, true ]
    ].freeze

    def self.call = new.call

    def call
      validate_execution!
      @reference_time = Time.zone.now.beginning_of_day
      previous_adapter = ActiveJob::Base.queue_adapter
      ActiveJob::Base.queue_adapter = :test
      seed_all
    ensure
      ActiveJob::Base.queue_adapter = previous_adapter if previous_adapter
    end

    private

    def validate_execution!
      raise Refused, "Demo mode must be enabled" unless DemoMode.enabled?
      if Rails.env.test? && !DemoMode.parse(ENV.fetch("DEMO_SEED_TEST", nil))
        raise Refused, "Set DEMO_SEED_TEST=true for an isolated automated test"
      end
      if Rails.env.production? && !DemoMode.parse(ENV.fetch("DEMO_STORAGE_ISOLATED", nil))
        raise Refused, "Confirm isolated demo storage with DEMO_STORAGE_ISOLATED=true"
      end
    end

    def seed_all
      accounts = seed_accounts
      setting = seed_setting
      categories = seed_categories
      brands = seed_brands
      products = seed_products(categories, brands, accounts.fetch(:inventory_manager))
      zones = seed_delivery_zones
      addresses = seed_addresses(accounts, zones)
      promotions, coupons = seed_promotions(accounts.fetch(:admin), categories, products, zones)
      seed_ready_cart(accounts.fetch(:customer), products, coupons.fetch(:active))
      orders = seed_orders(accounts, addresses, products, zones, promotions, coupons)
      setting.class.invalidate_cache
      build_manifest(accounts, categories, brands, products, zones, orders, promotions, coupons)
    end

    def seed_accounts
      DemoData::Accounts::DEFINITIONS.to_h do |key, definition|
        user = User.find_or_initialize_by(email: definition[:email])
        user.assign_attributes(first_name: definition[:first_name], last_name: definition[:last_name],
          mobile_number: definition[:mobile], role: definition[:role], active: true)
        password = password_for(key)
        user.password = password unless user.persisted? && user.valid_password?(password)
        if definition[:role] != :customer
          user.otp_secret = totp_secret unless user.otp_secret == totp_secret
          user.otp_enabled_at ||= @reference_time
        end
        user.save!
        [ key, user ]
      end
    end

    def password_for(key)
      value = ENV["DEMO_#{key.to_s.upcase}_PASSWORD"] || ENV["DEMO_ACCOUNT_PASSWORD"]
      return value if value.present?
      return "DemoOnly123!" if Rails.env.development? || Rails.env.test?

      raise Refused, "Missing demo password environment variable for #{key}"
    end

    def totp_secret
      ENV["DEMO_TOTP_SECRET"].presence || (return "JBSWY3DPEHPK3PXP" if Rails.env.development? || Rails.env.test?)
      raise Refused, "Missing DEMO_TOTP_SECRET"
    end

    def seed_setting
      PharmacySetting.find_or_initialize_by(singleton_key: 1).tap do |setting|
        setting.update!(pharmacy_name: "صيدلية الروضة التجريبية", legal_name: "صيدلية الروضة للعرض فقط",
          support_email: "support@example.test", support_mobile: "01000000999",
          address_summary: "عنوان خيالي — حي الروضة التجريبي، القاهرة", support_hours: "يوميًا من 9 ص إلى 10 م",
          footer_text: "بيئة عرض ببيانات خيالية — لا تُستخدم لطلبات أو وصفات حقيقية", default_currency: "EGP",
          default_locale: "ar", time_zone: "Africa/Cairo", order_number_prefix: "DEMO", prescription_review_enabled: true,
          guest_cart_enabled: true, customer_registration_enabled: true, default_low_stock_threshold: 5,
          default_maximum_order_quantity: 10, default_reservation_minutes: 30,
          pending_prescription_reservation_hours: 24, maintenance_mode: false,
          sender_email: "demo@example.test", sender_name: "صيدلية الروضة التجريبية")
      end
    end

    def seed_categories
      CATEGORY_DATA.each_with_index.to_h do |(slug, name, icon), position|
        category = Category.find_or_initialize_by(slug:)
        category.update!(name:, description: "تصنيف تجريبي لعرض منتجات #{name} دون تقديم ادعاءات طبية.", icon:, position:, active: true)
        [ slug, category ]
      end
    end

    def seed_brands
      BRAND_DATA.to_h do |slug, name|
        brand = Brand.find_or_initialize_by(slug:)
        brand.update!(name:, description: "علامة خيالية مخصصة لبيانات العرض.", active: true)
        [ slug, brand ]
      end
    end

    def seed_products(categories, brands, inventory_actor)
      PRODUCT_DATA.each_with_index.to_h do |data, index|
        suffix, name, category_slug, brand_slug, price, compare_at, stock, prescription, featured, active = data
        slug = "demo-#{suffix}"
        product = Product.find_or_initialize_by(slug:)
        new_product = product.new_record?
        product.assign_attributes(name:, short_description: "منتج خيالي مخصص لعرض واجهة الصيدلية.",
          description: "بيانات عرض فقط. راجع مختصًا قبل استخدام أي منتج صحي.", category: categories.fetch(category_slug),
          brand: brands.fetch(brand_slug), price:, compare_at_price: compare_at, cost_price: (price * 0.7).round(2),
          requires_prescription: prescription, pharmacist_review_required: prescription, featured:, active: active != false,
          sku: format("DEMO-%03d", index + 1), barcode: format("29900000%05d", index + 1), low_stock_threshold: 5,
          maximum_order_quantity: 10, published_at: @reference_time - 60.days)
        product.stock_quantity = stock if new_product
        product.save!
        if new_product && stock.positive?
          product.inventory_movements.create!(actor: inventory_actor, movement_type: :opening_balance,
            quantity_delta: stock, quantity_before: 0, quantity_after: stock, reason: "رصيد افتتاحي لبيانات العرض",
            idempotency_key: "demo:opening:#{slug}", created_at: @reference_time - 60.days)
        end
        [ suffix, product ]
      end
    end

    def seed_delivery_zones
      data = [
        [ "demo-roda", "حي الروضة التجريبي", "القاهرة", "مدينة نصر", 2500, 5000, true ],
        [ "demo-nile", "منطقة النيل التجريبية", "الجيزة", "الدقي", 3500, 7500, true ],
        [ "demo-garden", "منطقة الحدائق التجريبية", "القاهرة", "المعادي", 4500, 10000, true ],
        [ "demo-paused", "منطقة متوقفة للعرض", "القاهرة", "مدينة خيالية", 5000, 10000, false ]
      ]
      data.each_with_index.to_h do |(code, name, governorate, city, fee, minimum, active), position|
        zone = DeliveryZone.find_or_initialize_by(code:)
        zone.update!(name:, governorate:, city:, delivery_fee_cents: fee, minimum_order_cents: minimum,
          free_delivery_threshold_cents: 100_000, estimated_min_minutes: 45 + position * 15,
          estimated_max_minutes: 120 + position * 30, same_day_available: active, scheduled_delivery_available: active,
          cash_on_delivery_available: true, active:, position:)
        district_name = position.zero? ? "المنطقة السادسة" : city
        zone.districts.find_or_initialize_by(normalized_name: Delivery::Normalizer.call(district_name)).update!(name: district_name, active: true)
        DeliveryMethod::CODES.each_with_index do |method_code, method_position|
          zone.delivery_methods.find_or_initialize_by(code: method_code).update!(name: { "standard" => "توصيل عادي", "scheduled" => "توصيل مجدول", "pharmacy_pickup" => "استلام من الصيدلية" }.fetch(method_code), additional_fee_cents: method_code == "scheduled" ? 1000 : 0, active:, position: method_position)
        end
        [ code, zone ]
      end
    end

    def seed_addresses(accounts, zones)
      accounts.slice(:customer, :prescription_customer, :cancelled_customer).to_h do |key, user|
        zone = key == :cancelled_customer ? zones.fetch("demo-nile") : zones.fetch("demo-roda")
        address = user.addresses.find_or_initialize_by(label: "عنوان العرض")
        address.update!(recipient_name: user.full_name, mobile_number: user.mobile_number, governorate: zone.governorate,
          city: zone.city, district: zone.districts.first.name, street: "شارع المثال", building_number: "#{user.id}",
          floor: "2", apartment: "4", landmark: "بجوار ميدان خيالي", default: true, active: true)
        [ key, address ]
      end
    end

    def seed_promotions(admin, categories, products, zones)
      definitions = {
        active: [ "demo:active-cart", "خصم 10٪ على طلب العرض", "cart", "percentage", 10, @reference_time - 7.days, @reference_time + 30.days, true ],
        fixed: [ "demo:fixed-vitamins", "خصم ثابت على الفيتامينات", "category", "fixed_amount", 2500, @reference_time - 2.days, @reference_time + 20.days, true ],
        expired: [ "demo:expired", "عرض منتهي", "cart", "fixed_amount", 1500, @reference_time - 30.days, @reference_time - 1.day, false ],
        future: [ "demo:future", "عرض قادم", "delivery", "free_delivery", 0, @reference_time + 7.days, @reference_time + 37.days, false ]
      }
      promotions = definitions.to_h do |key, data|
        internal, name, type, discount_type, value, starts_at, ends_at, active = data
        promotion = Promotion.find_or_initialize_by(internal_name: internal)
        promotion.update!(name:, description: "حملة خيالية لعرض نظام العروض.", promotion_type: type,
          discount_type:, discount_value: value, starts_at:, ends_at:, active:, automatic: false,
          minimum_subtotal_cents: 5000, maximum_discount_cents: 5000, total_usage_limit: 50,
          per_customer_usage_limit: 2, priority: 10, stackable: false, created_by: admin, updated_by: admin,
          delivery_zone: type == "delivery" ? zones.fetch("demo-roda") : nil)
        promotion.categories = [ categories.fetch("demo-vitamins") ] if key == :fixed
        [ key, promotion ]
      end
      coupons = {
        active: [ promotions[:active], "DEMO10", true, nil, nil ],
        limited: [ promotions[:fixed], "VITA25", true, 5, 1 ],
        expired: [ promotions[:expired], "OLD15", false, 10, 1 ],
        future: [ promotions[:future], "SOONFREE", false, 10, 1 ]
      }.to_h do |key, (promotion, code, active, total_limit, customer_limit)|
        coupon = Coupon.find_or_initialize_by(normalized_code: code)
        coupon.update!(promotion:, code:, active:, authenticated_only: false, minimum_subtotal_cents: 5000,
          total_usage_limit: total_limit, per_customer_usage_limit: customer_limit)
        [ key, coupon ]
      end
      [ promotions, coupons ]
    end

    def seed_ready_cart(customer, products, coupon)
      cart = customer.carts.find_or_initialize_by(status: :active)
      cart.update!(currency: "EGP", applied_coupon: coupon, applied_coupon_code_snapshot: coupon.code)
      cart.items.find_or_initialize_by(product: products.fetch("daily-moisturizer")).update!(quantity: 1)
      cart.items.find_or_initialize_by(product: products.fetch("vitamin-c")).update!(quantity: 2)
    end

    def seed_orders(accounts, addresses, products, zones, promotions, coupons)
      scenarios = [
        [ "DEMO-PRESCRIPTION-NEW", :prescription_customer, "pending_prescription", "rx-tablets-a", 0, :submitted ],
        [ "DEMO-PRESCRIPTION-REVIEW", :prescription_customer, "pending_prescription", "rx-capsules-b", 1, :under_review ],
        [ "DEMO-PRESCRIPTION-APPROVED", :customer, "submitted", "rx-suspension-c", 4, :approved ],
        [ "DEMO-PRESCRIPTION-REJECTED", :cancelled_customer, "rejected", "rx-tablets-a", 8, :rejected ],
        [ "DEMO-CONFIRMED", :customer, "confirmed", "gentle-cleanser", 2, nil ],
        [ "DEMO-PREPARING", :customer, "preparing", "baby-wipes", 3, nil ],
        [ "DEMO-READY", :customer, "ready_for_delivery", "vitamin-c", 6, nil ],
        [ "DEMO-OUT-FOR-DELIVERY", :customer, "out_for_delivery", "first-aid-kit", 10, nil ],
        [ "DEMO-DELIVERED-OLD", :customer, "delivered", "daily-moisturizer", 25, nil ],
        [ "DEMO-CANCELLED", :cancelled_customer, "cancelled", "digital-thermometer", 12, nil ]
      ]
      scenarios.map do |number, account_key, status, product_key, days_ago, prescription_status|
        ensure_order(number:, user: accounts.fetch(account_key), address: addresses.fetch(account_key), status:,
          product: products.fetch(product_key), zone: account_key == :cancelled_customer ? zones.fetch("demo-nile") : zones.fetch("demo-roda"),
          days_ago:, prescription_status:, pharmacist: accounts.fetch(:pharmacist), order_manager: accounts.fetch(:order_manager),
          promotion: number == "DEMO-DELIVERED-OLD" ? promotions.fetch(:active) : nil,
          coupon: number == "DEMO-DELIVERED-OLD" ? coupons.fetch(:active) : nil)
      end
    end

    def ensure_order(number:, user:, address:, status:, product:, zone:, days_ago:, prescription_status:, pharmacist:, order_manager:, promotion:, coupon:)
      return Order.find_by!(number:) if Order.exists?(number:)

      submitted_at = @reference_time - days_ago.days + 10.hours
      Cart.transaction do
        cart = user.carts.create!(status: :completed, currency: "EGP", checkout_submission_token: "demo:cart:#{number}")
        quantity = 1
        subtotal = (product.price * 100).round * quantity
        discount = promotion ? [ (subtotal * 0.1).round, 5000 ].min : 0
        fee = zone.delivery_fee_cents
        cancellation = status == "cancelled" ? { cancellation_reason: "إلغاء تجريبي بطلب العميل", cancellation_source: :customer, cancelled_by: user, cancelled_at: submitted_at + 1.hour } : {}
        order = user.orders.create!(cart:, number:, status:, payment_method: :cash_on_delivery,
          payment_status: status == "delivered" ? :paid : :unpaid, delivery_method: :standard, currency: "EGP",
          subtotal_cents: subtotal, discount_cents: discount, cart_discount_cents: discount,
          product_discount_cents: 0, delivery_discount_cents: 0, delivery_fee_cents: fee,
          total_cents: subtotal - discount + fee, customer_email: user.email, customer_mobile_number: user.mobile_number,
          customer_first_name: user.first_name, customer_last_name: user.last_name, submitted_at:,
          confirmed_at: %w[confirmed preparing ready_for_delivery out_for_delivery delivered].include?(status) ? submitted_at + 1.hour : nil,
          prescription_required: prescription_status.present?, delivery_zone: zone, delivery_zone_code: zone.code,
          delivery_zone_name: zone.name, delivery_method_name: "توصيل عادي", delivery_estimated_min_minutes: zone.estimated_min_minutes,
          delivery_estimated_max_minutes: zone.estimated_max_minutes, pricing_calculation_version: Promotions::Calculator::VERSION,
          **cancellation)
        item = order.items.create!(product:, product_name: product.name, product_slug: product.slug,
          brand_name: product.brand.name, category_name: product.category.name, quantity:,
          unit_price_cents: subtotal - discount, original_unit_price_cents: subtotal,
          final_unit_price_cents: subtotal - discount, discount_cents: discount,
          line_total_cents: subtotal - discount, requires_prescription: product.requires_prescription?)
        reservation = order.inventory_reservations.create!(order_item: item, product:, quantity:, status: :active,
          expires_at: %w[confirmed preparing].include?(status) ? nil : submitted_at + 24.hours)
        if %w[ready_for_delivery out_for_delivery delivered].include?(status)
          raise Refused, "Insufficient demo stock for #{product.slug}" unless Inventory::ConsumeReservations.new(order).call
        elsif %w[cancelled rejected].include?(status)
          Inventory::ReleaseReservations.new(order).call
        end
        order.create_order_address!(address.attributes.symbolize_keys.slice(:label, :recipient_name, :mobile_number,
          :governorate, :city, :district, :street, :building_number, :floor, :apartment, :landmark, :postal_code,
          :delivery_notes, :latitude, :longitude))
        fulfilment_status = { "ready_for_delivery" => :packed, "out_for_delivery" => :dispatched, "delivered" => :delivered }.fetch(status, :unassigned)
        order.create_fulfilment!(delivery_zone: zone, status: fulfilment_status, assigned_to: fulfilment_status == :unassigned ? nil : order_manager,
          assigned_by: fulfilment_status == :unassigned ? nil : order_manager, assigned_at: fulfilment_status == :unassigned ? nil : submitted_at + 2.hours,
          dispatched_at: fulfilment_status.in?(%i[dispatched delivered]) ? submitted_at + 4.hours : nil,
          delivered_at: fulfilment_status == :delivered ? submitted_at + 6.hours : nil)
        order.events.create!(event_type: "order_submitted", to_status: status, customer_visible: true, created_at: submitted_at)
        create_prescription(order, user, prescription_status, pharmacist, submitted_at) if prescription_status
        create_promotion_snapshot(order, user, promotion, coupon, discount, submitted_at) if promotion
        reservation
        order
      end
    end

    def create_prescription(order, user, status, pharmacist, submitted_at)
      prescription = order.build_prescription(user:, status: :submitted, submitted_at:, customer_notes: "ملاحظة خيالية لبيانات العرض")
      prescription.images.attach(io: File.open(Rails.root.join("db/demo_assets/prescription.pdf")), filename: "demo-prescription.pdf", content_type: "application/pdf")
      prescription.save!
      attributes = { scan_status: :clean, scanned_at: submitted_at + 5.minutes, status: }
      if %i[approved rejected].include?(status)
        attributes.merge!(reviewed_by: pharmacist, reviewed_at: submitted_at + 1.hour,
          customer_message: status == :approved ? "تمت مراجعة الملف التجريبي" : "الملف التجريبي غير مكتمل",
          rejection_reason: status == :rejected ? "الملف التجريبي غير مكتمل" : nil)
      elsif status == :under_review
        attributes[:internal_notes] = "مراجعة تجريبية جارية"
      end
      prescription.update!(attributes)
    end

    def create_promotion_snapshot(order, user, promotion, coupon, discount, submitted_at)
      order.order_promotions.create!(promotion:, coupon:, promotion_name: promotion.name, code: coupon.code,
        promotion_type: promotion.promotion_type, discount_type: promotion.discount_type,
        discount_value_snapshot: promotion.discount_value, discount_cents: discount, metadata: { demo: true })
      order.promotion_redemptions.create!(promotion:, coupon:, user:, code_snapshot: coupon.code,
        discount_cents: discount, status: :redeemed, redeemed_at: submitted_at)
    end

    def build_manifest(accounts, categories, brands, products, zones, orders, promotions, coupons)
      Manifest.new(accounts: accounts.size, categories: categories.size, brands: brands.size, products: products.size,
        inventory_movements: InventoryMovement.where("idempotency_key LIKE 'demo:%'").count,
        customers: accounts.values.count(&:customer?), prescriptions: orders.count { |order| order.prescription.present? },
        orders: orders.size, promotions: promotions.size, coupons: coupons.size, delivery_zones: zones.size)
    end
  end
end
