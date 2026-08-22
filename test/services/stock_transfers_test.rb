require "test_helper"

class StockTransfersTest < ActiveSupport::TestCase
  setup do
    @source = branches(:main)
    @destination = Branch.create!(code: "NASR", name: "Nasr City", active: true, timezone: "Africa/Cairo")
    @actor = users(:admin)
    @actor.branch_memberships.find_or_create_by!(branch: @source)
    @actor.branch_memberships.find_or_create_by!(branch: @destination)
    @product = products(:featured)
    @batch = inventory_batches(:featured_primary)
  end

  test "dispatch removes source stock and receipt creates traced destination stock exactly once" do
    transfer = StockTransfer.create!(number: "TR-TEST-1", source_branch: @source,
      destination_branch: @destination, created_by: @actor)
    transfer.items.create!(product: @product, requested_quantity: 3)
    assert StockTransfers::Workflow.new(transfer:, actor: @actor, action: :submit).call.success?
    assert_difference -> { @batch.reload.on_hand_quantity }, -3 do
      assert StockTransfers::Workflow.new(transfer:, actor: @actor, action: :dispatch).call.success?
    end
    assert_equal 0, InventoryBatch.where(branch: @destination, product: @product).sum(:on_hand_quantity)
    assert_difference -> { InventoryBatch.where(branch: @destination, product: @product).sum(:on_hand_quantity) }, 3 do
      assert StockTransfers::Workflow.new(transfer:, actor: @actor, action: :receive).call.success?
    end
    assert StockTransfers::Workflow.new(transfer:, actor: @actor, action: :receive).call.success?
    allocation = transfer.items.first.batch_allocations.first
    assert_equal @batch, allocation.destination_inventory_batch.source_inventory_batch
    assert_equal %w[branch_transfer_out branch_transfer_in], InventoryMovement.where(reference: transfer).order(:id).map(&:movement_type)
    assert transfer.reload.received?
    assert StockTransfers::Workflow.new(transfer:, actor: @actor, action: :close).call.success?
    assert transfer.reload.closed?
  end


  test "submitted transfer can be cancelled without stock movement" do
    transfer = StockTransfer.create!(number: "TR-TEST-CANCEL", source_branch: @source,
      destination_branch: @destination, created_by: @actor, cancellation_reason: "تغير الاحتياج")
    transfer.items.create!(product: @product, requested_quantity: 1)
    StockTransfers::Workflow.new(transfer:, actor: @actor, action: :submit).call
    assert_no_difference -> { InventoryMovement.count } do
      assert StockTransfers::Workflow.new(transfer:, actor: @actor, action: :cancel).call.success?
    end
    assert transfer.reload.cancelled?
    assert_equal @actor, transfer.cancelled_by
  end

  test "dispatch is transactional when branch stock is insufficient" do
    transfer = StockTransfer.create!(number: "TR-TEST-2", source_branch: @source,
      destination_branch: @destination, created_by: @actor)
    transfer.items.create!(product: @product, requested_quantity: @batch.on_hand_quantity + 1)
    StockTransfers::Workflow.new(transfer:, actor: @actor, action: :submit).call
    assert_no_difference -> { @batch.reload.on_hand_quantity } do
      refute StockTransfers::Workflow.new(transfer:, actor: @actor, action: :dispatch).call.success?
    end
    assert_empty transfer.items.first.batch_allocations
    assert transfer.reload.submitted?
  end

  test "non admin actor needs access to both transfer branches" do
    actor = users(:inventory_manager)
    actor.branch_memberships.find_or_create_by!(branch: @source)
    transfer = StockTransfer.create!(number: "TR-TEST-3", source_branch: @source,
      destination_branch: @destination, created_by: actor)
    transfer.items.create!(product: @product, requested_quantity: 1)

    result = StockTransfers::Workflow.new(transfer:, actor:, action: :submit).call

    refute result.success?
    assert transfer.reload.draft?
  end
end
