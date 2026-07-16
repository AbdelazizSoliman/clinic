module Settings
  class Update
    Result = Data.define(:success?, :setting, :errors)

    def initialize(actor:, setting:, attributes:, reason:)
      @actor, @setting, @attributes, @reason = actor, setting, attributes, reason.to_s.strip
    end

    def call
      return Result.new(success?: false, setting: @setting, errors: [ "غير مصرح" ]) unless @actor&.can_manage_application_settings?
      old = @setting.attributes.slice(*@attributes.keys.map(&:to_s))
      @setting.assign_attributes(@attributes)
      return Result.new(success?: false, setting: @setting, errors: @setting.errors.full_messages) unless @setting.save
      SettingsAuditEvent.create!(actor: @actor, old_values: old, new_values: @setting.attributes.slice(*old.keys), reason: @reason)
      PharmacySetting.invalidate_cache
      Result.new(success?: true, setting: @setting, errors: [])
    rescue ActiveRecord::StaleObjectError
      Result.new(success?: false, setting: @setting, errors: [ "تم تعديل الإعدادات بواسطة مدير آخر" ])
    end
  end
end
