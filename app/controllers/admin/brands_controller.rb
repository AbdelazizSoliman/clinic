module Admin
  class BrandsController < BaseController
    before_action :set_brand, only: %i[edit update destroy deactivate]
    def index
      scope = Brand.with_attached_logo.left_joins(:products).group(:id).order(:name)
      scope = scope.where("brands.name ILIKE ?", "%#{Brand.sanitize_sql_like(params[:q])}%") if params[:q].present?
      @brands = scope
    end
    def new = @brand = Brand.new
    def edit; end
    def create
      @brand = Brand.new
      persist(:new, "brand_created")
    end
    def update = persist(:edit, "brand_updated")
    def deactivate
      @brand.update!(active: false)
      audit("brand_deactivated")
      redirect_to admin_brands_path, notice: "تم إيقاف العلامة التجارية"
    end
    def destroy
      return redirect_to(admin_brands_path, alert: "لا يمكن حذف علامة مرتبطة بمنتجات") if @brand.products.exists?
      @brand.destroy!
      redirect_to admin_brands_path, notice: "تم حذف العلامة"
    end
    private
    def set_brand = @brand = Brand.find(params[:id])
    def brand_params = params.require(:brand).permit(:name, :slug, :description, :website_url, :active, :logo, :lock_version)
    def persist(template, action)
      if @brand.update(brand_params)
        audit(action)
        redirect_to admin_brands_path, notice: "تم حفظ العلامة"
      else
        render template, status: :unprocessable_entity
      end
    rescue ActiveRecord::StaleObjectError
      redirect_to admin_brands_path, alert: "تم تحديث العلامة بواسطة مستخدم آخر"
    end
    def audit(action) = AdminAuditEvent.create!(actor: current_user, auditable: @brand, action:, change_data: @brand.saved_changes.except("updated_at"))
  end
end
