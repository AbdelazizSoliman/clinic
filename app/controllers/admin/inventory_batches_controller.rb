module Admin
  class InventoryBatchesController < BaseController
    before_action :set_batch, only: %i[show adjust quarantine release_quarantine]

    def index
      scope = InventoryBatch.includes(:product, :supplier).order(:expiry_date, :received_at, :id)
      scope = scope.where(product_id: params[:product_id]) if params[:product_id].present?
      scope = scope.where(supplier_id: params[:supplier_id]) if params[:supplier_id].present?
      scope = scope.expired if params[:state] == "expired"
      scope = scope.near_expiry(days: threshold) if params[:state] == "near_expiry"
      scope = scope.where.not(quarantined_at: nil) if params[:state] == "quarantined"
      @pagy, @batches = pagy(scope, limit: 30)
    end

    def show
      @movements = @batch.inventory_movements.includes(:actor, :reference).order(:created_at)
      @allocations = @batch.reservation_allocations.includes(inventory_reservation: { order: :user }).order(:created_at)
      @events = @batch.events.includes(:actor).order(:created_at)
    end

    def adjust
      delta = Integer(params[:quantity], exception: false).to_i.abs
      delta = -delta if %w[manual_decrease damaged expired batch_loss].include?(params[:movement_type])
      result = Inventory::AdjustBatch.new(batch: @batch, actor: current_user, movement_type: params[:movement_type],
        quantity_delta: delta, reason: params[:reason], lock_version: params[:lock_version]).call
      redirect_result(result, "تم تعديل رصيد التشغيلة وتسجيل الحركة")
    end

    def quarantine
      result = Inventory::ChangeQuarantine.new(batch: @batch, actor: current_user, quarantined: true,
        reason: params[:reason], lock_version: params[:lock_version]).call
      redirect_result(result, "تم عزل التشغيلة عن الحجز والصرف")
    end

    def release_quarantine
      result = Inventory::ChangeQuarantine.new(batch: @batch, actor: current_user, quarantined: false,
        reason: params[:reason], lock_version: params[:lock_version]).call
      redirect_result(result, "تم رفع العزل عن التشغيلة")
    end

    private

    def set_batch = @batch = InventoryBatch.find(params[:id])
    def threshold = PharmacySetting.current.near_expiry_threshold_days || 90
    def redirect_result(result, message)
      redirect_to admin_inventory_batch_path(@batch), status: :see_other,
        flash: { result.success? ? :notice : :alert => result.success? ? message : result.errors.join("، ") }
    end
  end
end
