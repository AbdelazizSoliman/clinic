class AccountController < ApplicationController
  before_action :authenticate_user!

  def show; end

  def edit; end

  def update
    attributes = account_params
    updated = if attributes[:email].present? && attributes[:email] != current_user.email
      current_user.update_with_password(attributes)
    else
      attributes.delete(:current_password)
      current_user.update(attributes)
    end

    if updated
      redirect_to account_path, notice: "تم تحديث بيانات الحساب بنجاح"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def account_params
    params.require(:user).permit(:first_name, :last_name, :mobile_number, :email, :current_password)
  end
end
