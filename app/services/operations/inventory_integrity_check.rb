module Operations
  class InventoryIntegrityCheck < SqlIntegrityCheck
    def call
      findings([
        [ :product_batch_stock_mismatch, :critical, "SELECT p.id FROM products p WHERE p.stock_quantity<>(SELECT COALESCE(SUM(b.on_hand_quantity),0) FROM inventory_batches b WHERE b.product_id=p.id AND b.organization_id=p.organization_id)" ],
        [ :invalid_batch_quantities, :critical, "SELECT id FROM inventory_batches WHERE on_hand_quantity<0 OR reserved_quantity<0 OR returned_quarantine_quantity<0 OR reserved_quantity+returned_quarantine_quantity>on_hand_quantity" ],
        [ :reservation_branch_mismatch, :critical, "SELECT r.id FROM inventory_reservations r JOIN orders o ON o.id=r.order_id WHERE r.branch_id<>o.branch_id OR r.organization_id<>o.organization_id" ],
        [ :allocation_batch_mismatch, :critical, "SELECT a.id FROM inventory_reservation_allocations a JOIN inventory_reservations r ON r.id=a.inventory_reservation_id JOIN inventory_batches b ON b.id=a.inventory_batch_id WHERE a.organization_id<>r.organization_id OR a.organization_id<>b.organization_id OR r.branch_id<>b.branch_id" ],
        [ :movement_arithmetic_mismatch, :critical, "SELECT id FROM inventory_movements WHERE quantity_after<>quantity_before+quantity_delta" ],
        [ :movement_branch_mismatch, :critical, "SELECT m.id FROM inventory_movements m JOIN inventory_batches b ON b.id=m.inventory_batch_id WHERE m.inventory_batch_id IS NOT NULL AND (m.branch_id<>b.branch_id OR m.organization_id<>b.organization_id)" ],
        [ :transfer_receipt_incomplete, :critical, "SELECT t.id FROM stock_transfers t JOIN stock_transfer_items i ON i.stock_transfer_id=t.id WHERE t.status=4 GROUP BY t.id HAVING SUM(i.received_quantity)<>SUM(i.dispatched_quantity)" ],
        [ :transfer_destination_before_receipt, :critical, "SELECT a.id FROM stock_transfer_batch_allocations a JOIN stock_transfer_items i ON i.id=a.stock_transfer_item_id JOIN stock_transfers t ON t.id=i.stock_transfer_id WHERE t.status<3 AND a.destination_inventory_batch_id IS NOT NULL" ]
      ])
    end
  end
end
