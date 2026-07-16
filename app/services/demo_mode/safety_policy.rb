module DemoMode
  class SafetyPolicy
    class ProtectedActionError < StandardError; end

    def self.enforce!(action, protected_actions: Rails.application.config.x.demo_protected_actions)
      return true unless DemoMode.enabled? && protected_actions.map(&:to_sym).include?(action.to_sym)

      raise ProtectedActionError, "This action is unavailable in demo mode"
    end
  end
end
