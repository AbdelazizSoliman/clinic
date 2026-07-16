module Users
  class PasswordsController < Devise::PasswordsController
    def create
      email = params.dig(:user, :email).to_s.downcase
      return protected_response if DemoData::Accounts.protected?(User.find_by(email:))

      super
    end

    def update
      return protected_response if DemoData::Accounts.protected?(user_for_reset_token)

      super
    end

    private

    def user_for_reset_token
      token = params.dig(:user, :reset_password_token)
      return if token.blank?

      digest = Devise.token_generator.digest(User, :reset_password_token, token)
      User.find_by(reset_password_token: digest)
    end

    def protected_response
      redirect_to new_user_session_path,
        notice: "إذا كان البريد مسجلًا فستصلك تعليمات الاستعادة. حسابات العرض المحمية يديرها مشغّل العرض.",
        status: :see_other
    end
  end
end
