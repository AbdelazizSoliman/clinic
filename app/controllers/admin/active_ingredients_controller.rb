module Admin
  class ActiveIngredientsController < BaseController
    before_action :set_ingredient, only: %i[show edit update deactivate]

    def index
      scope = ActiveIngredient.order(:name)
      scope = scope.where(ingredient_match, ingredient_pattern, ingredient_code) if params[:q].present?
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

    # Reuses the shared normalizer so admins find ingredients with the same Arabic
    # spelling tolerance as the storefront, without coupling clinical administration to
    # the public product-search service.
    def ingredient_match = "search_name LIKE ? OR upper(code) = ?"
    def ingredient_pattern = "%#{ActiveIngredient.sanitize_sql_like(Search::ArabicNormalizer.normalize(params[:q]))}%"
    def ingredient_code = Search::ArabicNormalizer.normalize_identifier(params[:q]).upcase

    def set_ingredient = @ingredient = ActiveIngredient.find(params[:id])
    def ingredient_params = params.require(:active_ingredient).permit(:code, :name, :active, :notes)

    def audit(action, change_data)
      AdminAuditEvent.create!(actor: current_user, auditable: @ingredient, action:, change_data:)
    end
  end
end
