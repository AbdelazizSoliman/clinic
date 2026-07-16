module Reports
  class FulfilmentPerformance
    Result = Data.define(:status_counts, :average_assignment_seconds, :assignment_sample_count, :average_delivery_seconds, :delivery_sample_count, :zones, :slots, :workload)
    def initialize(range) = @range = range
    def call
      scope = Fulfilment.where(created_at: @range.range)
      assigned = scope.where.not(assigned_at: nil)
      delivered = scope.where.not(dispatched_at: nil, delivered_at: nil)
      slots = DeliverySlot.where(delivery_date: @range.start_at.in_time_zone("Africa/Cairo").to_date..(@range.end_at.in_time_zone("Africa/Cairo").to_date - 1))
      Result.new(status_counts: scope.group(:status).count,
        average_assignment_seconds: assigned.average("EXTRACT(EPOCH FROM (assigned_at - created_at))")&.to_i,
        assignment_sample_count: assigned.count,
        average_delivery_seconds: delivered.average("EXTRACT(EPOCH FROM (delivered_at - dispatched_at))")&.to_i,
        delivery_sample_count: delivered.count, zones: scope.joins(:delivery_zone).group("delivery_zones.name").count,
        slots: slots.group(:delivery_zone_id).pluck(:delivery_zone_id, Arel.sql("SUM(capacity)"), Arel.sql("SUM(booked_count)")),
        workload: scope.where.not(assigned_to_id: nil).joins(:assigned_to).group("users.first_name", "users.last_name").count)
    end
  end
end
