class TwoFactorEnrollmentsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_privileged_user

  def show
    redirect_to root_path, notice: t("security.two_factor.already_enabled") if current_user.two_factor_enabled?
  end

  def create
    unless current_user.valid_password?(params[:current_password])
      return redirect_to two_factor_enrollment_path, alert: t("security.two_factor.invalid_password")
    end
    secret = ROTP::Base32.random
    session[:pending_otp_secret] = secret
    @provisioning_uri = ROTP::TOTP.new(secret, issuer: "صيدليتي").provisioning_uri(current_user.email)
    @qr = RQRCode::QRCode.new(@provisioning_uri)
    render :confirm
  end

  def update
    secret = session[:pending_otp_secret]
    unless secret.present? && ROTP::TOTP.new(secret).verify(params[:otp_code].to_s, drift_behind: 30, drift_ahead: 30)
      return redirect_to two_factor_enrollment_path, alert: t("security.two_factor.invalid_code")
    end
    current_user.update!(otp_secret: secret, otp_enabled_at: Time.current)
    @recovery_codes = current_user.regenerate_recovery_codes!
    session.delete(:pending_otp_secret)
    session[:session_version] = current_user.session_version
    SecurityEvent.record("two_factor_enabled", user: current_user, actor: current_user, request: request)
  end

  private

  def require_privileged_user
    head(:not_found) unless current_user.privileged?
  end
end
