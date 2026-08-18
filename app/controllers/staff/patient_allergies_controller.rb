module Staff
  class PatientAllergiesController < BaseController
    before_action :authorize_clinical!
    before_action :set_patient

    def create
      profile = PatientClinicalProfile.find_by(user: @patient)
      return redirect_back_with("سجّل الملف السريري أولًا", :alert) unless profile
      result = PatientProfiles::RecordAllergy.new(profile:, actor: current_user,
        active_ingredient: ActiveIngredient.find_by(id: params[:active_ingredient_id]),
        severity: params[:severity], notes: params[:notes]).call
      redirect_back_with(result.success? ? "تم تسجيل الحساسية" : result.errors.join("، "),
        result.success? ? :notice : :alert)
    end

    def destroy
      allergy = PatientAllergy.joins(:patient_clinical_profile)
        .where(patient_clinical_profiles: { user_id: @patient.id }).find(params[:id])
      result = PatientProfiles::RecordAllergy.deactivate(allergy:, actor: current_user)
      redirect_back_with(result.success? ? "تم إيقاف سجل الحساسية مع الاحتفاظ بتاريخه" : result.errors.join("، "),
        result.success? ? :notice : :alert)
    end

    private

    def authorize_clinical!
      head :not_found unless current_user.can_manage_clinical_profiles?
    end

    def set_patient = @patient = User.customer.find(params[:patient_id])

    def redirect_back_with(message, level)
      redirect_to staff_patient_clinical_profile_path(@patient), status: :see_other, flash: { level => message }
    end
  end
end
