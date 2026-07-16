module Admin
  class CategoriesController < BaseController
    before_action :set_category, only: %i[edit update destroy deactivate]
    def index
      scope = Category.with_attached_image.left_joins(:products).group(:id).order(:position, :name)
      scope = scope.where("categories.name ILIKE ?", "%#{Category.sanitize_sql_like(params[:q])}%") if params[:q].present?
      @categories = scope
    end
    def new = @category = Category.new
    def edit; end
    def create
      @category = Category.new(category_params)
      persist(@category, "category_created", :new)
    end
    def update = persist(@category, "category_updated", :edit)
    def deactivate
      @category.update!(active: false)
      audit(@category, "category_deactivated")
      redirect_to admin_categories_path, notice: "تم إيقاف التصنيف"
    end
    def destroy
      return redirect_to(admin_categories_path, alert: "لا يمكن حذف تصنيف مرتبط بمنتجات") if @category.products.exists?
      @category.destroy!
      redirect_to admin_categories_path, notice: "تم حذف التصنيف"
    end
    private
    def set_category = @category = Category.find(params[:id])
    def category_params = params.require(:category).permit(:name, :slug, :description, :active, :position, :image, :lock_version)
    def persist(record, action, template)
      if record.update(category_params)
        audit(record, action)
        redirect_to admin_categories_path, notice: "تم حفظ التصنيف"
      else
        render template, status: :unprocessable_entity
      end
    rescue ActiveRecord::StaleObjectError
      redirect_to admin_categories_path, alert: "تم تحديث التصنيف بواسطة مستخدم آخر"
    end
    def audit(record, action) = AdminAuditEvent.create!(actor: current_user, auditable: record, action:, change_data: record.saved_changes.except("updated_at"))
  end
end
