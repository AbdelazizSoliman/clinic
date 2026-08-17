class AddPerItemPrescriptionReviews < ActiveRecord::Migration[8.1]
  OLD_ORDER_EVENT_TYPES = %w[order_submitted prescription_review_started prescription_approved
    prescription_partially_approved prescription_rejected order_confirmed preparation_started
    order_ready out_for_delivery delivered cancelled rejected reservations_released
    reservations_consumed follow_up_opened customer_responded follow_up_resolved customer_cancelled
    staff_cancelled system_cancelled reservations_extended reservations_expired notification_sent
    fulfilment_assigned delivery_scheduled fulfilment_picking fulfilment_packed delivery_dispatched
    delivery_completed].freeze
  NEW_ORDER_EVENT_TYPES = (OLD_ORDER_EVENT_TYPES + %w[prescription_line_review_completed]).freeze

  def up
    create_table :prescription_reviews do |t|
      t.references :reviewable, polymorphic: true, null: false
      t.integer :status, null: false, default: 0
      t.datetime :started_at
      t.datetime :completed_at
      t.references :started_by, foreign_key: { to_table: :users }
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :prescription_reviews, %i[reviewable_type reviewable_id], unique: true,
      name: "index_prescription_reviews_unique_reviewable"
    add_index :prescription_reviews, %i[status created_at]
    add_check_constraint :prescription_reviews, "status IN (0, 1, 2)",
      name: "prescription_reviews_status_valid"

    create_table :prescription_review_items do |t|
      t.references :prescription_review, null: false, foreign_key: true
      t.references :reviewable_item, polymorphic: true, null: false
      t.references :original_product, null: false, foreign_key: { to_table: :products }
      t.references :dispensed_product, foreign_key: { to_table: :products }
      t.integer :status, null: false, default: 0
      t.integer :quantity, null: false
      t.bigint :prescribed_unit_price_cents, null: false
      t.bigint :dispensed_unit_price_cents
      t.references :reviewed_by, foreign_key: { to_table: :users }
      t.datetime :reviewed_at
      t.text :reason
      t.text :pharmacist_notes
      t.string :physician_instruction_reference
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :prescription_review_items,
      %i[prescription_review_id reviewable_item_type reviewable_item_id],
      unique: true, name: "index_prescription_review_items_unique_source"
    add_index :prescription_review_items, %i[status reviewed_at]
    add_check_constraint :prescription_review_items, "status IN (0, 1, 2, 3, 4)",
      name: "prescription_review_items_status_valid"
    add_check_constraint :prescription_review_items, "quantity > 0",
      name: "prescription_review_items_quantity_positive"
    add_check_constraint :prescription_review_items,
      "prescribed_unit_price_cents >= 0 AND (dispensed_unit_price_cents IS NULL OR dispensed_unit_price_cents >= 0)",
      name: "prescription_review_items_money_nonnegative"
    add_check_constraint :prescription_review_items,
      "(status IN (0, 1) AND reviewed_by_id IS NULL AND reviewed_at IS NULL AND dispensed_product_id IS NULL) OR " \
      "(status = 2 AND reviewed_by_id IS NOT NULL AND reviewed_at IS NOT NULL AND dispensed_product_id = original_product_id) OR " \
      "(status = 3 AND reviewed_by_id IS NOT NULL AND reviewed_at IS NOT NULL AND dispensed_product_id IS NOT NULL AND dispensed_product_id <> original_product_id) OR " \
      "(status = 4 AND reviewed_by_id IS NOT NULL AND reviewed_at IS NOT NULL AND dispensed_product_id IS NULL)",
      name: "prescription_review_items_decision_consistent"

    create_table :therapeutic_substitutions do |t|
      t.references :prescription_review_item, null: false, foreign_key: true
      t.references :original_product, null: false, foreign_key: { to_table: :products }
      t.references :substitute_product, null: false, foreign_key: { to_table: :products }
      t.references :pharmacist, null: false, foreign_key: { to_table: :users }
      t.datetime :substituted_at, null: false
      t.text :reason, null: false
      t.string :physician_instruction_reference
      t.timestamps
    end
    add_index :therapeutic_substitutions, :prescription_review_item_id, unique: true,
      name: "index_therapeutic_substitutions_unique_item"
    add_check_constraint :therapeutic_substitutions,
      "original_product_id <> substitute_product_id",
      name: "therapeutic_substitutions_products_differ"

    create_table :prescription_decisions do |t|
      t.references :prescription_review_item, null: false, foreign_key: true
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.string :from_status, null: false
      t.string :to_status, null: false
      t.text :reason
      t.text :notes
      t.jsonb :metadata, null: false, default: {}
      t.datetime :created_at, null: false
    end
    add_index :prescription_decisions, %i[prescription_review_item_id created_at],
      name: "index_prescription_decisions_timeline"
    add_check_constraint :prescription_decisions,
      "from_status IN ('pending','under_review','approved','substituted','rejected') AND " \
      "to_status IN ('pending','under_review','approved','substituted','rejected')",
      name: "prescription_decisions_statuses_valid"

    remove_check_constraint :order_events, name: "order_events_type_valid"
    add_check_constraint :order_events,
      "event_type IN (#{NEW_ORDER_EVENT_TYPES.map { |type| connection.quote(type) }.join(', ')})",
      name: "order_events_type_valid"

    add_column :orders, :prescription_adjustment_cents, :bigint, null: false, default: 0
    remove_check_constraint :orders, name: "orders_money_nonnegative"
    add_check_constraint :orders,
      "subtotal_cents >= 0 AND discount_cents >= 0 AND delivery_fee_cents >= 0 AND total_cents >= 0",
      name: "orders_money_nonnegative"

    remove_index :inventory_reservations, name: "index_inventory_reservations_on_order_item_id"
    add_index :inventory_reservations, %i[order_item_id status], unique: true,
      name: "index_inventory_reservations_unique_line_status"

    release_pending_prescription_reservations

    backfill_online_reviews
    backfill_pos_reviews
  end

  def down
    remove_check_constraint :order_events, name: "order_events_type_valid"
    add_check_constraint :order_events,
      "event_type IN (#{OLD_ORDER_EVENT_TYPES.map { |type| connection.quote(type) }.join(', ')})",
      name: "order_events_type_valid"

    remove_check_constraint :orders, name: "orders_money_nonnegative"
    add_check_constraint :orders,
      "subtotal_cents >= 0 AND discount_cents >= 0 AND delivery_fee_cents >= 0 AND total_cents >= 0",
      name: "orders_money_nonnegative"
    remove_column :orders, :prescription_adjustment_cents
    remove_index :inventory_reservations, name: "index_inventory_reservations_unique_line_status"
    add_index :inventory_reservations, :order_item_id, unique: true
    drop_table :prescription_decisions
    drop_table :therapeutic_substitutions
    drop_table :prescription_review_items
    drop_table :prescription_reviews
  end

  private

  def release_pending_prescription_reservations
    execute <<~SQL
      UPDATE inventory_batches batches
      SET reserved_quantity = batches.reserved_quantity - released.quantity,
          updated_at = CURRENT_TIMESTAMP
      FROM (
        SELECT allocations.inventory_batch_id, SUM(allocations.quantity)::integer AS quantity
        FROM inventory_reservation_allocations allocations
        JOIN inventory_reservations reservations
          ON reservations.id = allocations.inventory_reservation_id AND reservations.status = 0
        JOIN order_items ON order_items.id = reservations.order_item_id
        JOIN prescriptions ON prescriptions.order_id = reservations.order_id
        WHERE order_items.requires_prescription = TRUE
          AND prescriptions.status IN (0, 1)
        GROUP BY allocations.inventory_batch_id
      ) released
      WHERE batches.id = released.inventory_batch_id
    SQL
    execute <<~SQL
      UPDATE inventory_reservations reservations
      SET status = 1, released_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
      FROM order_items, prescriptions
      WHERE reservations.order_item_id = order_items.id
        AND prescriptions.order_id = reservations.order_id
        AND reservations.status = 0
        AND order_items.requires_prescription = TRUE
        AND prescriptions.status IN (0, 1)
    SQL
  end

  def backfill_online_reviews
    execute <<~SQL
      INSERT INTO prescription_reviews
        (reviewable_type, reviewable_id, status, started_at, completed_at, started_by_id, lock_version, created_at, updated_at)
      SELECT 'Prescription', prescriptions.id,
        CASE WHEN prescriptions.status IN (2, 3, 4) THEN 2
             WHEN prescriptions.status = 1 THEN 1 ELSE 0 END,
        CASE WHEN prescriptions.status >= 1 THEN prescriptions.updated_at END,
        CASE WHEN prescriptions.status IN (2, 3, 4) THEN prescriptions.reviewed_at END,
        prescriptions.reviewed_by_id, 0, prescriptions.created_at, prescriptions.updated_at
      FROM prescriptions
    SQL
    execute <<~SQL
      INSERT INTO prescription_review_items
        (prescription_review_id, reviewable_item_type, reviewable_item_id, original_product_id,
         dispensed_product_id, status, quantity, prescribed_unit_price_cents, dispensed_unit_price_cents,
         reviewed_by_id, reviewed_at, reason, pharmacist_notes, lock_version, created_at, updated_at)
      SELECT reviews.id, 'OrderItem', order_items.id, order_items.product_id,
        CASE WHEN prescriptions.status IN (2, 3) THEN order_items.product_id END,
        CASE WHEN prescriptions.status IN (2, 3) THEN 2
             WHEN prescriptions.status = 4 THEN 4
             WHEN prescriptions.status = 1 THEN 1 ELSE 0 END,
        order_items.quantity, COALESCE(order_items.final_unit_price_cents, order_items.unit_price_cents, 0),
        CASE WHEN prescriptions.status IN (2, 3) THEN COALESCE(order_items.final_unit_price_cents, order_items.unit_price_cents, 0) END,
        CASE WHEN prescriptions.status IN (2, 3, 4) THEN prescriptions.reviewed_by_id END,
        CASE WHEN prescriptions.status IN (2, 3, 4) THEN prescriptions.reviewed_at END,
        CASE WHEN prescriptions.status = 4 THEN prescriptions.rejection_reason ELSE 'قرار مرحّل من مراجعة الطلب' END,
        prescriptions.internal_notes, 0, order_items.created_at, order_items.updated_at
      FROM prescriptions
      JOIN prescription_reviews reviews
        ON reviews.reviewable_type = 'Prescription' AND reviews.reviewable_id = prescriptions.id
      JOIN order_items ON order_items.order_id = prescriptions.order_id
      WHERE order_items.requires_prescription = TRUE AND order_items.product_id IS NOT NULL
    SQL
  end

  def backfill_pos_reviews
    execute <<~SQL
      INSERT INTO prescription_reviews
        (reviewable_type, reviewable_id, status, started_at, completed_at, started_by_id, lock_version, created_at, updated_at)
      SELECT 'PosSale', pos_sales.id,
        CASE WHEN pos_sales.status IN (1, 2) THEN 2 ELSE 0 END,
        NULL,
        CASE WHEN pos_sales.status IN (1, 2) THEN COALESCE(pos_sales.completed_at, pos_sales.voided_at) END,
        NULL, 0, pos_sales.created_at, pos_sales.updated_at
      FROM pos_sales
      WHERE EXISTS (
        SELECT 1 FROM pos_sale_items
        WHERE pos_sale_items.pos_sale_id = pos_sales.id
          AND pos_sale_items.requires_prescription = TRUE
      )
    SQL
    execute <<~SQL
      INSERT INTO prescription_review_items
        (prescription_review_id, reviewable_item_type, reviewable_item_id, original_product_id,
         dispensed_product_id, status, quantity, prescribed_unit_price_cents, dispensed_unit_price_cents,
         reviewed_by_id, reviewed_at, reason, lock_version, created_at, updated_at)
      SELECT reviews.id, 'PosSaleItem', items.id, items.product_id,
        CASE WHEN items.prescription_approved_by_id IS NOT NULL THEN items.product_id END,
        CASE WHEN items.prescription_approved_by_id IS NOT NULL THEN 2 ELSE 0 END,
        items.quantity, items.original_unit_price_cents,
        CASE WHEN items.prescription_approved_by_id IS NOT NULL THEN items.unit_price_cents END,
        items.prescription_approved_by_id, items.prescription_approved_at,
        items.prescription_approval_reason, 0, items.created_at, items.updated_at
      FROM pos_sale_items items
      JOIN prescription_reviews reviews
        ON reviews.reviewable_type = 'PosSale' AND reviews.reviewable_id = items.pos_sale_id
      WHERE items.requires_prescription = TRUE
    SQL
  end
end
