module Admin
  class SuppliersController < BaseController
    before_action :set_supplier, only: %i[show edit update destroy deactivate activate]

    def index
      @pagy, @suppliers = pagy(Admin::SuppliersQuery.new(Supplier.all, params.permit(:q, :active)).call, limit: 20)
    end
    def show; end
    def new = @supplier = Supplier.new(active: true)
    def edit; end

    def create
      @supplier = Supplier.new(supplier_params)
      if @supplier.save
        audit("supplier_created", @supplier.saved_changes)
        redirect_to admin_supplier_path(@supplier), notice: "تم إنشاء المورد"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @supplier.update(supplier_params)
        audit("supplier_updated", @supplier.saved_changes)
        redirect_to admin_supplier_path(@supplier), notice: "تم تحديث المورد"
      else
        render :edit, status: :unprocessable_entity
      end
    rescue ActiveRecord::StaleObjectError
      redirect_to edit_admin_supplier_path(@supplier), alert: "تم تحديث المورد بواسطة مستخدم آخر"
    end

    def deactivate
      @supplier.update!(active: false)
      audit("supplier_deactivated", active: [ true, false ])
      redirect_to admin_supplier_path(@supplier), notice: "تم إيقاف المورد مع الاحتفاظ بالتاريخ"
    end

    def activate
      @supplier.update!(active: true)
      audit("supplier_activated", active: [ false, true ])
      redirect_to admin_supplier_path(@supplier), notice: "تم تفعيل المورد"
    end

    def destroy
      return redirect_to(admin_supplier_path(@supplier), alert: "لا يمكن حذف مورد له تاريخ شراء") unless @supplier.destroyable?
      @supplier.destroy!
      redirect_to admin_suppliers_path, notice: "تم حذف المورد غير المستخدم"
    end

    private

    def set_supplier = @supplier = Supplier.find(params[:id])
    def supplier_params
      params.require(:supplier).permit(:name, :legal_name, :code, :contact_person, :phone, :email, :address,
        :tax_identifier, :payment_terms, :lead_time_days, :notes, :lock_version)
    end
    def audit(action, changes)
      AdminAuditEvent.create!(actor: current_user, auditable: @supplier, action:,
        change_data: changes.to_h.slice("name", "legal_name", "code", "contact_person", "phone", "email", "tax_identifier", "payment_terms", "lead_time_days", "active"))
    end
  end
end
