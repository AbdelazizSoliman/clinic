module Staff
  class DeliverySlotsController < DeliveryBaseController
    def create
      zone = DeliveryZone.find(params[:delivery_zone_id])
      slot = zone.delivery_slots.create!(slot_params)
      redirect_to staff_delivery_zone_path(zone), notice: "تمت إضافة موعد التوصيل"
    rescue ActiveRecord::RecordInvalid => error
      redirect_to staff_delivery_zone_path(zone), alert: error.record.errors.full_messages.join("، ")
    end
    def destroy
      zone = DeliveryZone.find(params[:delivery_zone_id])
      slot = zone.delivery_slots.find(params[:id])
      return redirect_to(staff_delivery_zone_path(zone), alert: "لا يمكن حذف موعد محجوز") if slot.booked_count.positive?
      slot.destroy!
      redirect_to staff_delivery_zone_path(zone), notice: "تم حذف الموعد"
    end
    private
    def slot_params = params.require(:delivery_slot).permit(:delivery_date, :starts_at, :ends_at, :capacity, :active)
  end
end
