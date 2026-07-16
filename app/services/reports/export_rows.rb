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
      rows = Prescription.where(submitted_at: @range.range).order(:submitted_at).limit(CsvExporter::MAX_ROWS + 1).map do |prescription|
        [ prescription.order.number, prescription.submitted_at, prescription.status, prescription.reviewed_at ]
      end
      Result.new(headers: %w[الطلب تاريخ_الإرسال الحالة تاريخ_المراجعة], rows:)
    end
    def fulfilments
      rows = Fulfilment.joins(:order).where(created_at: @range.range).includes(:delivery_zone, :assigned_to, :order).limit(CsvExporter::MAX_ROWS + 1).map do |fulfilment|
        [ fulfilment.order.number, fulfilment.status, fulfilment.delivery_zone&.name, fulfilment.assigned_to&.full_name,
          fulfilment.assigned_at, fulfilment.dispatched_at, fulfilment.delivered_at ]
      end
      Result.new(headers: %w[الطلب الحالة المنطقة المسؤول الإسناد الانطلاق التسليم], rows:)
    end
  end
end
