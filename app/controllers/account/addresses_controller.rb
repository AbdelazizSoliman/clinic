module Account
  class AddressesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_address, only: %i[edit update destroy set_default deactivate]

    def index
      @addresses = current_user.addresses.order(default: :desc, active: :desc, created_at: :desc)
    end

    def new
      @address = current_user.addresses.new(recipient_name: current_user.full_name, mobile_number: current_user.mobile_number)
    end

    def create
      @address = current_user.addresses.new
      if Addresses::Save.new(address: @address, attributes: address_params).call
        respond_saved("تم حفظ العنوان بنجاح")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if Addresses::Save.new(address: @address, attributes: address_params).call
        respond_saved("تم تحديث العنوان بنجاح")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      Addresses::Deactivate.new(@address).call
      redirect_to account_addresses_path, notice: "تم تعطيل العنوان بأمان", status: :see_other
    end

    def deactivate
      Addresses::Deactivate.new(@address).call
      redirect_to account_addresses_path, notice: "تم تعطيل العنوان", status: :see_other
    end

    def set_default
      notice = Addresses::SetDefault.new(@address).call ? "تم تعيين العنوان كافتراضي" : "لا يمكن تعيين عنوان غير نشط"
      redirect_to account_addresses_path, notice:, status: :see_other
    end

    private

    def set_address
      @address = current_user.addresses.find(params[:id])
    end

    def address_params
      params.require(:address).permit(:label, :recipient_name, :mobile_number, :governorate, :city, :district, :street, :building_number, :floor, :apartment, :landmark, :delivery_notes, :postal_code, :latitude, :longitude, :default)
    end

    def respond_saved(message)
      if turbo_frame_request?
        redirect_to checkout_path(address_id: @address.id), notice: message, status: :see_other
      else
        redirect_to account_addresses_path, notice: message, status: :see_other
      end
    end
  end
end
