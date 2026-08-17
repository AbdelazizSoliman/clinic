module Staff
  class PrescriptionReviewItemsController < BaseController
    before_action :authorize_visibility!
    before_action :set_records

    def start
      result = Prescriptions::StartLineReview.new(item: @review_item, actor: current_user,
        lock_version: params[:lock_version]).call
      redirect_with(result, "بدأت مراجعة البند")
    end

    def decide
      substitute = Product.find_by(id: params[:substitute_product_id]) if params[:decision] == "substituted"
      result = Prescriptions::DecideLine.new(item: @review_item, actor: current_user,
        decision: params[:decision], reason: params[:reason], notes: params[:notes],
        substitute_product: substitute,
        physician_instruction_reference: params[:physician_instruction_reference],
        lock_version: params[:lock_version]).call
      redirect_with(result, "تم حفظ القرار السريري للبند")
    end

    private

    def authorize_visibility!
      head :not_found unless current_user.can_review_prescriptions?
    end

    def set_records
      @prescription = Prescription.find(params[:prescription_id])
      review = Prescriptions::EnsureReview.call(@prescription)
      @review_item = review.items.find(params[:id])
    end

    def redirect_with(result, notice)
      redirect_to staff_prescription_path(@prescription), status: :see_other,
        flash: { result.success? ? :notice : :alert => result.success? ? notice : result.errors.join("، ") }
    end
  end
end
