module Admin
  class ActiveIngredientsController < BaseController
    before_action :set_ingredient, only: %i[show edit update deactivate]

    def index
      scope = ActiveIngredient.order(:name)
      scope = scope.where("name ILIKE :q OR code ILIKE :q", q: "%#{ActiveIngredient.sanitize_sql_like(params[:q])}%") if params[:q].present?
      scope = scope.where(active: params[:active] == "true") if %w[true false].include?(params[:active])
      @pagy, @ingredients = pagy(scope, limit: 25)
    end

    def show
      @products = @ingredient.product_active_ingredients.includes(:product).order("products.name")
    end

    def new = @ingredient = ActiveIngredient.new(active: true)
    def edit; end

    def create
      @ingredient = ActiveIngredient.new(ingredient_params)
      if @ingredient.save
        audit("active_ingredient_created", @ingredient.saved_changes.slice("code", "name", "active"))
        redirect_to admin_active_ingredient_path(@ingredient), notice: "تمت إضافة المادة الفعالة"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @ingredient.update(ingredient_params)
        audit("active_ingredient_updated", @ingredient.saved_changes.slice("code", "name", "active"))
        redirect_to admin_active_ingredient_path(@ingredient), notice: "تم تحديث المادة الفعالة"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def deactivate
      @ingredient.update!(active: false)
      audit("active_ingredient_deactivated", active: [ true, false ])
      redirect_to admin_active_ingredient_path(@ingredient), notice: "تم إيقاف المادة مع الاحتفاظ بالتاريخ"
    end

    private

    def set_ingredient = @ingredient = ActiveIngredient.find(params[:id])
    def ingredient_params = params.require(:active_ingredient).permit(:code, :name, :active, :notes)

    def audit(action, change_data)
      AdminAuditEvent.create!(actor: current_user, auditable: @ingredient, action:, change_data:)
    end
  end
end
