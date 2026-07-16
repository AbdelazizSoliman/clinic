module Admin
  module Users
    class Update
      Result = Data.define(:success?, :user, :errors)
      PROTECTED = %w[role active].freeze

      def initialize(actor:, user:, attributes:, reason:)
        @actor, @user, @attributes, @reason = actor, user, attributes.to_h.symbolize_keys, reason.to_s.strip
      end

      def call
        return failure("غير مصرح") unless @actor&.can_manage_users?
        sensitive = @attributes.keys.map(&:to_s).intersect?(PROTECTED)
        return failure("سبب التغيير مطلوب") if sensitive && @reason.blank?
        User.transaction do
          User.where(role: User.roles[:admin], active: true).lock.load
          @user.lock!
          return failure("لا يمكن تعطيل أو تخفيض آخر مدير نشط") if removes_active_admin? && User.admin.where(active: true).where.not(id: @user.id).none?
          old = @user.slice(:first_name, :last_name, :email, :mobile_number, :role, :active)
          @user.assign_attributes(@attributes)
          return Result.new(success?: false, user: @user, errors: @user.errors.full_messages) unless @user.save
          create_audits(old)
        end
        Result.new(success?: true, user: @user, errors: [])
      rescue ActiveRecord::StaleObjectError
        failure("تم تعديل الحساب بواسطة مستخدم آخر؛ أعد تحميل الصفحة")
      end

      private

      def removes_active_admin?
        @user.admin? && @user.active? && (@attributes[:active] == false || @attributes[:role].to_s != "admin" && @attributes.key?(:role))
      end

      def create_audits(old)
        current = @user.slice(:first_name, :last_name, :email, :mobile_number, :role, :active)
        action = if old["role"] != current["role"]
          "role_changed"
        elsif old["active"] != current["active"]
          current["active"] ? "activated" : "deactivated"
        else
          "profile_updated_by_admin"
        end
        UserAuditEvent.create!(user: @user, actor: @actor, action:, old_values: old, new_values: current, reason: @reason)
      end

      def failure(message) = Result.new(success?: false, user: @user, errors: [ message ])
    end
  end
end
