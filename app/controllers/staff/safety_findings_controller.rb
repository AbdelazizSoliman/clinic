module Staff
  # Clinical resolution of a safety finding. Only pharmacists may acknowledge or override;
  # order managers, inventory managers and cashiers are refused server-side.
  class SafetyFindingsController < BaseController
    before_action :authorize_resolution!
    before_action :set_finding

    def update
      result = DrugSafety::Acknowledge.new(finding: @finding, actor: current_user,
        action: params[:safety_action], reason: params[:reason], lock_version: params[:lock_version]).call
      redirect_to return_path, status: :see_other,
        flash: { result.success? ? :notice : :alert =>
          result.success? ? "تم تسجيل قرار الصيدلي بشأن التنبيه" : result.errors.join("، ") }
    end

    private

    def authorize_resolution!
      head :not_found unless current_user.can_resolve_safety_findings?
    end

    def set_finding
      @finding = DrugSafetyFinding.includes(drug_safety_evaluation: { prescription_review: :reviewable })
        .find(params[:id])
      @review = @finding.drug_safety_evaluation.prescription_review
    end

    def return_path
      @review.online? ? staff_prescription_path(@review.reviewable) : pos_sale_path(@review.reviewable)
    end
  end
end
