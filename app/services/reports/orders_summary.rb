module Reports
  class OrdersSummary
    Result = Data.define(:status_counts, :oldest_actionable, :cancellation_reasons, :durations)
    def initialize(range) = @range = range
    def call
      scope = Order.where(submitted_at: @range.range)
      Result.new(status_counts: scope.group(:status).count,
        oldest_actionable: scope.where(status: %i[pending_prescription submitted confirmed]).order(:submitted_at).limit(10),
        cancellation_reasons: scope.cancelled.where.not(cancellation_reason: [ nil, "" ]).group(:cancellation_reason).count,
        durations: duration_metrics(scope))
    end
    private
    def duration_metrics(scope)
      pairs = { confirmation: %w[order_submitted order_confirmed], preparation: %w[order_confirmed preparation_started], delivery: %w[delivery_dispatched delivery_completed] }
      pairs.to_h do |name, (from, to)|
        rows = OrderEvent.where(order_id: scope.select(:id), event_type: [ from, to ])
          .group(:order_id).having("COUNT(DISTINCT event_type) = 2")
          .pluck(Arel.sql("EXTRACT(EPOCH FROM (MAX(created_at) - MIN(created_at)))"))
        [ name, { average_seconds: rows.any? ? (rows.sum / rows.length).round : nil, sample_count: rows.length } ]
      end
    end
  end
end
