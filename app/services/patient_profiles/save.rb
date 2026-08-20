module PatientProfiles
  # Pharmacist-entered structured clinical facts. Nothing is inferred from notes, gender,
  # order history or free text: every value here was typed by a pharmacist.
  class Save
    Result = Data.define(:success?, :profile, :errors)
    PERMITTED = %i[date_of_birth pregnancy_status lactation_status notes].freeze

    def initialize(user:, actor:, attributes:, lock_version: nil)
      @user = user
      @actor = actor
      @attributes = attributes.to_h.symbolize_keys.slice(*PERMITTED)
      @lock_version = lock_version
    end

    def call
      return failure("تسجيل البيانات السريرية متاح للصيدلي فقط") unless @actor&.can_manage_clinical_profiles?
      return failure("البيانات السريرية تُسجل للعملاء فقط") unless @user&.customer?

      profile = PatientClinicalProfile.find_or_initialize_by(user: @user)
      before = profile.persisted? ? profile.attributes.slice(*PERMITTED.map(&:to_s)) : {}
      profile.assign_attributes(@attributes.merge(recorded_by: @actor, recorded_at: Time.current))
      profile.lock_version = @lock_version.to_i if @lock_version.present? && profile.persisted?
      return failure(profile.errors.full_messages) unless profile.save

      audit(profile, before)
      RefreshReviews.call(@user, actor: @actor)
      Result.new(success?: true, profile:, errors: [])
    rescue ActiveRecord::StaleObjectError
      failure("تم تحديث الملف السريري بواسطة مستخدم آخر؛ أعد تحميل الصفحة")
    end

    private

    # Audit records that clinical data changed and which fields, never the values themselves.
    def audit(profile, before)
      changed = profile.saved_changes.keys & PERMITTED.map(&:to_s)
      return if before.present? && changed.empty?
      AdminAuditEvent.create!(actor: @actor, auditable: profile, action: "patient_clinical_profile_recorded",
        metadata: { patient_id: @user.id, fields: changed.sort, created: before.blank? })
    end

    def failure(messages) = Result.new(success?: false, profile: nil, errors: Array(messages))
  end
end
