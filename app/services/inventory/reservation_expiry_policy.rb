module Inventory
  class ReservationExpiryPolicy
    DURATIONS = { "pending_prescription" => 24.hours, "submitted" => 30.minutes, "follow_up" => 24.hours }.freeze

    def self.expires_at_for(order, context: nil, from: Time.current)
      duration = context == :follow_up ? DURATIONS["follow_up"] : DURATIONS[order.status]
      from + duration if duration
    end
  end
end
