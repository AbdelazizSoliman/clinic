module Staff
  class PrescriptionsController < BaseController
    before_action :authorize_review!
    before_action :set_prescription, only: %i[show review]

    def index
      scope = Prescription.includes(order: :items).order(Arel.sql("CASE status WHEN 0 THEN 0 WHEN 1 THEN 1 ELSE 2 END"), submitted_at: :asc)
      scope = scope.where(status: params[:status]) if Prescription.statuses.key?(params[:status])
      scope = scope.joins(:order).where("orders.number ILIKE ?", "%#{Prescription.sanitize_sql_like(params[:q])}%") if params[:q].present?
      scope = scope.where(submitted_at: parsed_date(params[:date_from])..) if parsed_date(params[:date_from])
      scope = scope.where(submitted_at: ..parsed_date(params[:date_to]).end_of_day) if parsed_date(params[:date_to])
      @pagy, @prescriptions = pagy(scope, limit: 20)
    end

    def show; end

    def review
      result = Prescriptions::Review.new(prescription: @prescription, actor: current_user, decision: params[:decision], customer_message: params[:customer_message], internal_notes: params[:internal_notes], lock_version: params[:lock_version]).call
      redirect_to staff_prescription_path(@prescription), status: :see_other, flash: { result.success? ? :notice : :alert => result.success? ? "تم حفظ قرار المراجعة" : result.errors.join("، ") }
    end

    private

    def authorize_review!
      head :not_found unless current_user.can_review_prescriptions?
    end
    def set_prescription = @prescription = Prescription.includes(:reviewed_by, order: [ :items, :events ], images_attachments: :blob).find(params[:id])
    def parsed_date(value)
      Date.iso8601(value) if value.present?
    rescue Date::Error
      nil
    end
  end
end
