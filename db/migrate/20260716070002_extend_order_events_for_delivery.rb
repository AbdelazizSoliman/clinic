class ExtendOrderEventsForDelivery < ActiveRecord::Migration[7.2]
  TYPES = %w[order_submitted prescription_review_started prescription_approved prescription_partially_approved prescription_rejected order_confirmed preparation_started order_ready out_for_delivery delivered cancelled rejected reservations_released reservations_consumed follow_up_opened customer_responded follow_up_resolved customer_cancelled staff_cancelled system_cancelled reservations_extended reservations_expired notification_sent fulfilment_assigned delivery_scheduled fulfilment_picking fulfilment_packed delivery_dispatched delivery_completed].freeze
  def change
    remove_check_constraint :order_events, name: "order_events_type_valid"
    add_check_constraint :order_events, "event_type IN (#{TYPES.map { |type| connection.quote(type) }.join(', ')})", name: "order_events_type_valid"
  end
end
