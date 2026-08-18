module Reports
  class ExportRows
    Result = Data.define(:headers, :rows)
    REALIZED = SalesSummary::REALIZED
    def self.call(type, range)
      new(type, range).call
    end
    def initialize(type, range) = (@type, @range = type, range)
    def call
      send(@type)
    end
    private
    def sales
      rows = Order.where(submitted_at: @range.range).order(:submitted_at).limit(CsvExporter::MAX_ROWS + 1).map do |order|
        [ order.number, order.submitted_at, order.status, order.subtotal_cents, order.discount_cents,
          order.delivery_fee_cents, order.total_cents, order.currency ]
      end
      Result.new(headers: %w[رقم_الطلب التاريخ الحالة الإجمالي_الخام_قرش الخصم_قرش التوصيل_قرش الصافي_قرش العملة], rows:)
    end
    alias_method :orders, :sales
    def products
      rows = ProductPerformance.new(@range).call.limit(CsvExporter::MAX_ROWS + 1).map do |row|
        [ row.product_name, row.category_name, row.brand_name, row.units_sold, row.gross_cents, row.discount_cents, row.net_cents, row.order_count ]
      end
      Result.new(headers: %w[المنتج التصنيف العلامة الوحدات الإجمالي_الخام_قرش الخصم_قرش الصافي_قرش الطلبات], rows:)
    end
    def inventory
      rows = InventoryMovement.where(created_at: @range.range).includes(:product, :actor).order(:created_at).limit(CsvExporter::MAX_ROWS + 1).map do |movement|
        [ movement.created_at, movement.product.name, movement.movement_type, movement.quantity_before,
          movement.quantity_delta, movement.quantity_after, movement.actor&.full_name, movement.reason ]
      end
      Result.new(headers: %w[التاريخ المنتج النوع قبل التغير بعد المنفذ السبب], rows:)
    end
    def promotions
      rows = OrderPromotion.joins(:order).where(orders: { submitted_at: @range.range }).includes(:order).limit(CsvExporter::MAX_ROWS + 1).map do |snapshot|
        [ snapshot.order.number, snapshot.promotion_name, snapshot.code, snapshot.promotion_type,
          snapshot.discount_type, snapshot.discount_cents, snapshot.order.subtotal_cents, snapshot.order.total_cents ]
      end
      Result.new(headers: %w[الطلب الحملة الكوبون نوع_الحملة نوع_الخصم الخصم_قرش الخام_قرش الصافي_قرش], rows:)
    end
    def customers
      summary = CustomerSummary.new(@range).call
      rows = summary.address_distribution.map { |(governorate, city), count| [ governorate, city, count ] }
      Result.new(headers: %w[المحافظة المدينة عدد_العناوين], rows:)
    end
    def prescriptions
      scope = Prescription.where(submitted_at: @range.range)
      items = PrescriptionReviewItem.joins(:prescription_review)
        .where(prescription_review: { reviewable_type: "Prescription", reviewable_id: scope.select(:id) })
        .includes(:original_product, :dispensed_product, :reviewed_by, prescription_review: { reviewable: :order })
        .order(:id).limit(CsvExporter::MAX_ROWS + 1)
      rows = items.map do |item|
        order = item.prescription_review.reviewable.order
        [ order.number, item.status, item.original_product.name, item.dispensed_product&.name,
          item.reviewed_by&.full_name, item.reviewed_at, item.reason, batch_numbers(item) ]
      end
      Result.new(headers: %w[الطلب حالة_البند المنتج_الموصوف المنتج_المصروف الصيدلي تاريخ_القرار السبب التشغيلات], rows:)
    end
    def fulfilments
      rows = Fulfilment.joins(:order).where(created_at: @range.range).includes(:delivery_zone, :assigned_to, :order).limit(CsvExporter::MAX_ROWS + 1).map do |fulfilment|
        [ fulfilment.order.number, fulfilment.status, fulfilment.delivery_zone&.name, fulfilment.assigned_to&.full_name,
          fulfilment.assigned_at, fulfilment.dispatched_at, fulfilment.delivered_at ]
      end
      Result.new(headers: %w[الطلب الحالة المنطقة المسؤول الإسناد الانطلاق التسليم], rows:)
    end
    def purchasing
      rows = PurchaseReceiptItem.joins(:purchase_receipt, purchase_order_item: { purchase_order: :supplier })
        .where(purchase_receipts: { received_at: @range.range })
        .includes(purchase_receipt: { purchase_order: :supplier }, purchase_order_item: :product)
        .order("purchase_receipts.received_at").limit(CsvExporter::MAX_ROWS + 1).map do |item|
          receipt = item.purchase_receipt
          order = receipt.purchase_order
          [ receipt.received_at, order.number, receipt.reference, order.supplier.code, order.supplier.name,
            item.purchase_order_item.product_name_snapshot, item.quantity, item.unit_cost_cents,
            item.quantity * item.unit_cost_cents, order.currency ]
        end
      Result.new(headers: %w[التاريخ أمر_الشراء الإيصال كود_المورد المورد المنتج الكمية تكلفة_الوحدة_قرش الإجمالي_قرش العملة], rows:)
    end
    def batches
      rows = InventoryBatch.includes(:product, :supplier, :purchase_receipt).order(:expiry_date, :id)
        .limit(CsvExporter::MAX_ROWS + 1).map do |batch|
          [ batch.batch_number, batch.lot_number, batch.product.name, batch.supplier&.code,
            batch.purchase_receipt&.reference, batch.received_at, batch.expiry_date, batch.lifecycle_status,
            batch.original_quantity, batch.on_hand_quantity, batch.reserved_quantity, batch.available_quantity,
            batch.unit_cost_cents, batch.on_hand_quantity * batch.unit_cost_cents.to_i ]
        end
      Result.new(headers: %w[التشغيلة اللوط المنتج المورد الإيصال الاستلام الصلاحية الحالة الأصلية الفعلية المحجوزة المتاحة تكلفة_الوحدة_قرش القيمة_قرش], rows:)
    end
    def pos
      rows = PosSale.completed.where(completed_at: @range.range)
        .includes(:cashier, :cashier_session, :payments, items: :batch_allocations)
        .order(:completed_at).limit(CsvExporter::MAX_ROWS + 1).map do |sale|
          [ sale.number, sale.completed_at, sale.cashier.full_name, sale.cashier_session.identifier,
            sale.subtotal_cents, sale.automatic_discount_cents, sale.manual_discount_cents,
            sale.total_cents, sale.payments.map(&:payment_method).join("+"),
            sale.items.sum(&:quantity), sale.items.sum { |item| item.batch_allocations.size },
            sale.items.count(&:requires_prescription?) ]
        end
      Result.new(headers: %w[الإيصال التاريخ الكاشير الجلسة الخام_قرش الخصم_التلقائي_قرش الخصم_اليدوي_قرش الصافي_قرش طرق_الدفع الوحدات التشغيلات بنود_الروشتة], rows:)
    end
    # Rule-match workflow rows only: no patient identity and no matched clinical facts.
    def drug_safety
      rows = DrugSafetyFinding.where(created_at: @range.range)
        .includes(:drug_safety_rule, :resolved_by, drug_safety_evaluation: {},
          prescription_review_item: [ :original_product, :dispensed_product, { prescription_review: :reviewable } ])
        .order(:created_at).limit(CsvExporter::MAX_ROWS + 1).map do |finding|
          review = finding.prescription_review_item.prescription_review
          [ finding.created_at, finding.rule_identity, finding.rule_type_label, finding.severity,
            finding.blocking ? "نعم" : "لا", finding.status_label, review.online? ? "أونلاين" : "نقطة بيع",
            context_reference(review), finding.prescription_review_item.original_product.name,
            finding.prescription_review_item.dispensed_product&.name, finding.resolved_by&.full_name,
            finding.resolved_at, finding.drug_safety_evaluation.sequence ]
        end
      Result.new(headers: %w[التاريخ القاعدة النوع الخطورة موقف الحالة المصدر المرجع المنتج_الموصوف المنتج_المصروف
        المُقِر تاريخ_الإقرار إصدار_التقييم], rows:)
    end

    def context_reference(review)
      review.online? ? review.reviewable.order.number : review.reviewable.number
    end

    def batch_numbers(item)
      return nil unless item.reviewable_item.is_a?(OrderItem)
      item.reviewable_item.inventory_reservation&.inventory_batches&.pluck(:batch_number)&.join("+")
    end
  end
end
