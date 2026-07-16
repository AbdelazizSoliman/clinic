class UserInvitationMailer < ApplicationMailer
  def invite
    @invitation = params[:invitation]
    @user = @invitation.user
    @token = params[:token]
    @setting = PharmacySetting.current
    mail(to: @user.email, subject: "دعوة للانضمام إلى #{@setting.pharmacy_name}")
  end
end
