class InvitationsController < ApplicationController
  def show
    @token = params[:token]
    @invitation = UserInvitation.find_by(token_digest: UserInvitation.digest(@token))
    render :invalid, status: :not_found unless @invitation&.usable?
  end

  def update
    result = Invitations::Accept.new(token: params[:token], password: params[:password],
      password_confirmation: params[:password_confirmation]).call
    if result.success?
      sign_in(result.user)
      redirect_to account_path, notice: "تم تفعيل حسابك وتعيين كلمة المرور", status: :see_other
    else
      @token = params[:token]
      @errors = result.errors
      render :show, status: :unprocessable_entity
    end
  end
end
