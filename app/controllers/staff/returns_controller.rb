module Staff
  class ReturnsController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_visibility!
    before_action :find_return, only: %i[show review inspect_item receive refund confirm_refund close]
    layout "staff"

    def index
      @returns = ReturnRequest.includes(:source, :requested_by).order(created_at: :desc).limit(100)
    end

    def new
      @source = find_source
      @return_request = ReturnRequest.new
    end

    def create
      source = find_source
      result = Returns::Create.new(source:, actor: current_user, items: item_specs,
        customer_notes: params.dig(:return_request, :customer_notes)).call
      if result.success?
        redirect_to staff_return_path(result.record), notice: "تم إنشاء المرتجع", status: :see_other
      else
        @source, @return_request = source, result.record || ReturnRequest.new
        flash.now[:alert] = result.errors.join("، ")
        render :new, status: :unprocessable_entity
      end
    end

    def show; end

    def review
      result = Returns::Review.new(return_request: @return_request, actor: current_user,
        approve: params[:decision] == "approve", notes: params[:notes]).call
      redirect_result(result)
    end

    def inspect_item
      item = @return_request.items.find(params[:item_id])
      result = Returns::Inspect.new(item:, actor: current_user, condition: params[:condition],
        disposition: params[:disposition], notes: params[:notes]).call
      redirect_result(result)
    end

    def receive
      result = Returns::Receive.new(return_request: @return_request, actor: current_user,
        dispositions: params.fetch(:dispositions, ActionController::Parameters.new)
          .permit(*@return_request.items.map { |item| item.id.to_s }).to_h,
        idempotency_key: params[:idempotency_key]).call
      redirect_result(result)
    end

    def refund
      result = Returns::Refund.new(return_request: @return_request, actor: current_user,
        amount_cents: params[:amount_cents], payment_method: params[:payment_method],
        external_reference: params[:external_reference], notes: params[:notes],
        idempotency_key: params[:idempotency_key]).call
      redirect_result(result)
    end

    def confirm_refund
      record = @return_request.refunds.find(params[:refund_id])
      result = Returns::ConfirmRefund.new(refund: record, actor: current_user,
        external_reference: params[:external_reference]).call
      redirect_result(result)
    end

    def close
      redirect_result(Returns::Close.new(return_request: @return_request, actor: current_user).call)
    end

    private

    def authorize_visibility!
      allowed = current_user&.can_initiate_returns? || current_user&.can_review_returns? ||
        current_user&.can_disposition_returns? || current_user&.can_refund_returns?
      head(:not_found) unless allowed
    end

    def find_return
      @return_request = ReturnRequest.includes(items: [ :source_item, :dispensed_product, { batch_allocations: :inventory_batch } ],
        refunds: :actor).find_by!(number: params[:number])
    end

    def find_source
      type = params[:source_type].to_s
      number = params[:source_number].to_s.strip
      type == "pos" ? PosSale.completed.find_by!(number:) : Order.delivered.find_by!(number:)
    end

    def item_specs
      params.fetch(:items, {}).values.filter_map do |value|
        permitted = value.permit(:source_item_id, :quantity, :reason, :condition, :reason_notes).to_h
        permitted if permitted["quantity"].to_i.positive?
      end
    end

    def redirect_result(result)
      redirect_to staff_return_path(@return_request), status: :see_other,
        flash: { result.success? ? :notice : :alert => result.success? ? "تم تنفيذ الإجراء" : result.errors.join("، ") }
    end
  end
end
