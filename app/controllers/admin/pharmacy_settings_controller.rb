module Admin
  class PharmacySettingsController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_settings!
    layout "admin"

    def edit
      @setting = PharmacySetting.first_or_initialize
    end

    def update
      @setting = PharmacySetting.first_or_initialize
      result = Settings::Update.new(actor: current_user, setting: @setting, attributes: setting_params, reason: params[:reason]).call
      if result.success?
        redirect_to edit_admin_pharmacy_setting_path, notice: "تم حفظ إعدادات الصيدلية", status: :see_other
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def authorize_settings!
      head(:not_found) unless current_user.can_manage_application_settings?
    end
    def setting_params
      params.require(:pharmacy_setting).permit(:pharmacy_name, :legal_name, :support_email, :support_mobile,
        :address_summary, :support_hours, :footer_text, :default_currency, :default_locale, :time_zone,
        :order_number_prefix, :prescription_review_enabled, :guest_cart_enabled, :customer_registration_enabled,
        :default_low_stock_threshold, :default_maximum_order_quantity, :default_reservation_minutes,
        :pending_prescription_reservation_hours, :sender_email, :sender_name, :maintenance_mode,
        :maintenance_message, :logo, :lock_version)
    end
  end
end
