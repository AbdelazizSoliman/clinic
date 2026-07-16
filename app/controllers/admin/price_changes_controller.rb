module Admin
  class PriceChangesController < BaseController
    def index
      scope = ProductPriceChange.includes(:product, :changed_by).order(effective_at: :desc)
      scope = scope.where(product_id: params[:product_id]) if params[:product_id].present?
      @pagy, @price_changes = pagy(scope, limit: 30)
    end
    def show = @price_change = ProductPriceChange.includes(:product, :changed_by).find(params[:id])
  end
end
