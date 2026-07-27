module Inventory
  class AllocateFefo
    Result = Data.define(:success?, :allocations, :errors)

    def initialize(reservation:)
      @reservation = reservation
    end

    def call
      allocations = []
      InventoryReservation.transaction do
        @reservation.lock!
        return success(@reservation.reservation_allocations.to_a) if @reservation.reservation_allocations.exists?
        batches = InventoryBatch.where(product_id: @reservation.product_id).allocatable.fefo.lock.to_a
        remaining = @reservation.quantity
        batches.each do |batch|
          quantity = [ remaining, batch.available_quantity ].min
          next unless quantity.positive?
          allocations << @reservation.reservation_allocations.create!(inventory_batch: batch, quantity:)
          batch.update!(reserved_quantity: batch.reserved_quantity + quantity)
          remaining -= quantity
          break if remaining.zero?
        end
        raise ActiveRecord::Rollback if remaining.positive?
      end
      return failure("الكمية المتاحة في التشغيلات غير كافية") unless allocations.sum(&:quantity) == @reservation.quantity
      success(allocations)
    rescue ActiveRecord::RecordInvalid => error
      failure(error.record.errors.full_messages.join("، "))
    end

    private

    def success(allocations) = Result.new(success?: true, allocations:, errors: [])
    def failure(message) = Result.new(success?: false, allocations: [], errors: [ message ])
  end
end
