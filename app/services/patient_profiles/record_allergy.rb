module PatientProfiles
  # Adds or reactivates one structured allergy entry keyed on a stable active-ingredient identity.
  class RecordAllergy
    Result = Data.define(:success?, :allergy, :errors)

    def initialize(profile:, actor:, active_ingredient:, severity:, notes: nil)
      @profile = profile
      @actor = actor
      @ingredient = active_ingredient
      @severity = severity.to_s.presence || "major"
      @notes = notes.to_s.squish.presence
    end

    def call
      return failure("تسجيل الحساسية متاح للصيدلي فقط") unless @actor&.can_manage_clinical_profiles?
      return failure("اختر مادة فعالة معتمدة") unless @ingredient&.active?
      return failure("مستوى الخطورة غير صحيح") unless DrugSafety::SEVERITIES.key?(@severity.to_sym)

      allergy = @profile.allergies.find_or_initialize_by(active_ingredient: @ingredient)
      allergy.assign_attributes(severity: @severity, notes: @notes, active: true,
        recorded_by: @actor, recorded_at: Time.current)
      return failure(allergy.errors.full_messages) unless allergy.save

      audit(allergy, "patient_allergy_recorded")
      RefreshReviews.call(@profile.user, actor: @actor)
      Result.new(success?: true, allergy:, errors: [])
    end

    def self.deactivate(allergy:, actor:)
      return Result.new(success?: false, allergy:, errors: [ "تعديل الحساسية متاح للصيدلي فقط" ]) unless actor&.can_manage_clinical_profiles?
      allergy.update!(active: false, recorded_by: actor, recorded_at: Time.current)
      AdminAuditEvent.create!(actor:, auditable: allergy.patient_clinical_profile, action: "patient_allergy_deactivated",
        metadata: { patient_id: allergy.patient_clinical_profile.user_id, ingredient_code: allergy.active_ingredient.code })
      RefreshReviews.call(allergy.patient_clinical_profile.user, actor:)
      Result.new(success?: true, allergy:, errors: [])
    end

    private

    def audit(allergy, action)
      AdminAuditEvent.create!(actor: @actor, auditable: @profile, action:,
        metadata: { patient_id: @profile.user_id, ingredient_code: allergy.active_ingredient.code,
          severity: allergy.severity })
    end

    def failure(messages) = Result.new(success?: false, allergy: nil, errors: Array(messages))
  end
end
