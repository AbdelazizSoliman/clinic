module Reports
  class CustomerSummary
    QUALIFYING = Order.statuses.except("cancelled", "rejected").values.freeze
    Result = Data.define(:new_customers, :purchasers, :repeat_customers, :first_time_purchasers, :returning_customers, :average_orders, :average_order_cents, :address_distribution)
    def initialize(range) = @range = range
    def call
      qualifying = Order.where(status: QUALIFYING)
      in_range = qualifying.where(submitted_at: @range.range)
      purchaser_ids = in_range.distinct.pluck(:user_id)
      first_orders = qualifying.group(:user_id).minimum(:submitted_at)
      Result.new(new_customers: User.customer.where(created_at: @range.range).count,
        purchasers: purchaser_ids.length, repeat_customers: qualifying.group(:user_id).having("COUNT(*) >= 2").count.length,
        first_time_purchasers: first_orders.count { |_id, time| @range.range.cover?(time) },
        returning_customers: purchaser_ids.count { |id| qualifying.where(user_id: id).where("submitted_at < ?", @range.start_at).exists? },
        average_orders: purchaser_ids.empty? ? nil : (in_range.count.to_f / purchaser_ids.length).round(2),
        average_order_cents: in_range.average(:total_cents)&.to_i,
        address_distribution: Address.where(active: true).group(:governorate, :city).count)
    end
  end
end
