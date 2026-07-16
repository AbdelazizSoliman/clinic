module Admin
  class UsersController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_users!
    before_action :set_user, only: %i[show edit update activate deactivate unlock resend_invitation revoke_sessions]
    layout "admin"

    def index
      @pagy, @users = pagy(Admin::UsersQuery.new(User.all, filter_params).call, limit: 25)
    end

    def show
      @events = @user.user_audit_events.includes(:actor).order(created_at: :desc).limit(30)
    end

    def new
      @user = User.new(active: false)
    end

    def create
      result = Admin::Users::Invite.new(actor: current_user, attributes: user_params).call
      @user = result.user || User.new(user_params)
      if result.success?
        redirect_to admin_user_path(result.user), notice: "تم إنشاء المستخدم وإرسال الدعوة", status: :see_other
      else
        result.errors.each { |error| @user.errors.add(:base, error) }
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      apply_update(profile_params)
    end

    def activate
      apply_update(active: true)
    end

    def deactivate
      apply_update(active: false)
    end

    def unlock
      @user.unlock_access!
      UserAuditEvent.create!(user: @user, actor: current_user, action: "account_unlocked", reason: params[:reason])
      redirect_to admin_user_path(@user), notice: "تم فتح الحساب", status: :see_other
    end

    def resend_invitation
      if Admin::Users::ResendInvitation.new(actor: current_user, user: @user).call
        redirect_to admin_user_path(@user), notice: "تم إرسال دعوة جديدة", status: :see_other
      else
        redirect_to admin_user_path(@user), alert: "لا يمكن إعادة الدعوة لهذا الحساب", status: :see_other
      end
    end

    def revoke_sessions
      @user.increment!(:session_version)
      SecurityEvent.record("sessions_revoked", user: @user, actor: current_user, request: request)
      redirect_to admin_user_path(@user), notice: t("security.sessions_revoked")
    end

    private

    def authorize_users!
      head(:not_found) unless current_user.can_manage_users?
    end

    def set_user = @user = User.find(params[:id])
    def filter_params = params.slice(:q, :role, :active, :never_signed_in, :from, :to, :sort).permit!
    def user_params = params.require(:user).permit(:first_name, :last_name, :email, :mobile_number, :role).to_h.symbolize_keys
    def profile_params = params.require(:user).permit(:first_name, :last_name, :email, :mobile_number, :role).to_h.symbolize_keys

    def apply_update(attributes)
      result = Admin::Users::Update.new(actor: current_user, user: @user, attributes:, reason: params[:reason]).call
      if result.success?
        redirect_to admin_user_path(@user), notice: "تم تحديث الحساب", status: :see_other
      else
        result.errors.each { |error| @user.errors.add(:base, error) }
        render :edit, status: :unprocessable_entity
      end
    end
  end
end
