module Staff
  class PatientClinicalProfilesController < BaseController
    before_action :authorize_clinical!
    before_action :set_patient

    def show
      @profile = PatientClinicalProfile.includes(allergies: :active_ingredient).find_by(user: @patient) ||
        PatientClinicalProfile.new(user: @patient)
      @ingredients = ActiveIngredient.active.order(:name)
    end

    def update
      result = PatientProfiles::Save.new(user: @patient, actor: current_user,
        attributes: profile_params, lock_version: params[:lock_version]).call
      redirect_to staff_patient_clinical_profile_path(@patient), status: :see_other,
        flash: { result.success? ? :notice : :alert =>
          result.success? ? "تم حفظ البيانات السريرية المسجلة" : result.errors.join("، ") }
    end

    private

    def authorize_clinical!
      head :not_found unless current_user.can_manage_clinical_profiles?
    end

    def set_patient
      @patient = User.customer.find(params[:patient_id])
    end

    def profile_params
      params.require(:patient_clinical_profile).permit(:date_of_birth, :pregnancy_status, :lactation_status, :notes)
    end
  end
end
