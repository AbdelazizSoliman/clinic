module Users
  class RegistrationsController < Devise::RegistrationsController
    before_action :ensure_registration_enabled, only: %i[new create]

    def create
      super do |user|
        next unless user.persisted?

        user.update_column(:role, User.roles[:customer]) unless user.customer?
        merged = Carts::MergeGuestCart.new(session:, user:).call
        flash[:notice] = "مرحبًا بك! تم حفظ سلة التسوق في حسابك" if merged.positive?
      end
    end

    private

    def ensure_registration_enabled
      return if PharmacySetting.current.customer_registration_enabled?
      redirect_to new_user_session_path, alert: "تسجيل العملاء متوقف مؤقتًا. يمكنك تسجيل الدخول بحساب موجود."
    end
  end
end
