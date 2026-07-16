module Staff
  class DeliveryZonesController < DeliveryBaseController
    before_action :set_zone, only: %i[show edit update destroy deactivate]
    def index
      scope = DeliveryZone.includes(:districts, :delivery_methods).order(:position, :name)
      scope = scope.where("name ILIKE ? OR code ILIKE ?", "%#{DeliveryZone.sanitize_sql_like(params[:q])}%", "%#{DeliveryZone.sanitize_sql_like(params[:q])}%") if params[:q].present?
      @pagy, @delivery_zones = pagy(scope, limit: 24)
    end
    def show
      @delivery_zone = @zone
    end
    def new = @delivery_zone = @zone = DeliveryZone.new(active: true, estimated_min_minutes: 60, estimated_max_minutes: 120)
    def edit; end
    def create
      @delivery_zone = @zone = DeliveryZone.new(zone_params)
      if @zone.save
        sync_children
        redirect_to staff_delivery_zone_path(@zone), notice: "تم إنشاء منطقة التوصيل"
      else
        render :new, status: :unprocessable_entity
      end
    end
    def update
      @delivery_zone = @zone
      if @zone.update(zone_params)
        sync_children
        redirect_to staff_delivery_zone_path(@zone), notice: "تم تحديث منطقة التوصيل"
      else
        render :edit, status: :unprocessable_entity
      end
    rescue ActiveRecord::StaleObjectError
      redirect_to edit_staff_delivery_zone_path(@zone), alert: "تم تحديث المنطقة بواسطة مستخدم آخر"
    end
    def deactivate
      @zone.update!(active: false)
      redirect_to staff_delivery_zones_path, notice: "تم إيقاف منطقة التوصيل"
    end
    def destroy
      return redirect_to(staff_delivery_zone_path(@zone), alert: "لا يمكن حذف منطقة مستخدمة") if @zone.orders.exists? || @zone.delivery_slots.exists?
      @zone.destroy!
      redirect_to staff_delivery_zones_path, notice: "تم حذف المنطقة"
    end
    private
    def set_zone = @delivery_zone = @zone = DeliveryZone.find(params[:id])
    def zone_params
      params.require(:delivery_zone).permit(:name, :code, :governorate, :city, :active, :delivery_fee_cents,
        :free_delivery_threshold_cents, :minimum_order_cents, :estimated_min_minutes, :estimated_max_minutes,
        :same_day_available, :scheduled_delivery_available, :cash_on_delivery_available, :position, :lock_version)
    end
    def sync_children
      Array(params[:districts]).flat_map { |value| value.to_s.split("،") }.map(&:squish).reject(&:blank?).each { |name| @zone.districts.find_or_create_by!(normalized_name: Delivery::Normalizer.call(name)) { |record| record.name = name } }
      %w[standard scheduled pharmacy_pickup].each_with_index do |code, position|
        next if code == "scheduled" && !@zone.scheduled_delivery_available?
        @zone.delivery_methods.find_or_create_by!(code:) { |method| method.assign_attributes(name: I18n.t("orders.delivery_methods.#{code}", default: code), position:) }
      end
    end
  end
end
