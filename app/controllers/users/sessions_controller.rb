module Users
  class SessionsController < Devise::SessionsController
    def create
      super do |user|
        session[:session_version] = user.session_version
        if user.privileged? && user.two_factor_enabled?
          return_to = stored_location_for(user)
          sign_out(user)
          session[:pre_2fa_user_id] = user.id
          session[:pre_2fa_return_to] = return_to
          return redirect_to(two_factor_challenge_path)
        end
        merged = Carts::MergeGuestCart.new(session:, user:).call
        flash[:notice] = "تم تسجيل الدخول ودمج #{merged} منتج من سلة الضيف" if merged.positive?
      end
    end

    def destroy
      reset_session
      redirect_to new_user_session_path, notice: I18n.t("devise.sessions.signed_out")
    end
  end
end
