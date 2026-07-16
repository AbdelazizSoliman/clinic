module DemoMode
  class SafetyPolicy
    class ProtectedActionError < StandardError; end
    PROTECTED_ACCOUNT_ATTRIBUTES = %i[email role active otp_secret otp_enabled_at encrypted_password].freeze

    def self.enforce!(action, protected_actions: Rails.application.config.x.demo_protected_actions)
      return true unless DemoMode.enabled? && protected_actions.map(&:to_sym).include?(action.to_sym)

      raise ProtectedActionError, "This action is unavailable in demo mode"
    end

    def self.protect_demo_account!(user, attributes:)
      return true unless DemoData::Accounts.protected?(user)
      return true unless attributes.to_h.symbolize_keys.keys.intersect?(PROTECTED_ACCOUNT_ATTRIBUTES)

      raise ProtectedActionError, "لا يمكن تغيير هوية أو صلاحيات حساب العرض المحمي"
    end
  end
end
