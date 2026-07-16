class TwoFactorChallengesController < ApplicationController
  skip_before_action :enforce_session_version
  skip_before_action :enforce_privileged_two_factor

  def show
    redirect_to new_user_session_path unless pending_user
  end

  def create
    user = pending_user
    valid = user&.active? && (user.verify_totp(params[:code]) || user.consume_recovery_code(params[:recovery_code]))
    unless valid
      return redirect_to two_factor_challenge_path, alert: t("security.two_factor.invalid_code")
    end
    sign_in(user)
    session.delete(:pre_2fa_user_id)
    session[:session_version] = user.session_version
    SecurityEvent.record("privileged_sign_in", user:, request: request)
    redirect_to session.delete(:pre_2fa_return_to).presence || after_sign_in_path_for(user)
  end

  private

  def pending_user = User.find_by(id: session[:pre_2fa_user_id])
end
