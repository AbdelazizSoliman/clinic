module Admin
  class PromotionsQuery
    SORTS = { "name" => { name: :asc }, "newest" => { created_at: :desc }, "priority" => { priority: :desc, id: :asc } }.freeze
    def initialize(relation, params)
      @relation, @params = relation, params
    end
    def call
      scope = @relation
      scope = scope.where(promotion_type: @params[:type]) if Promotion::TYPES.include?(@params[:type])
      scope = scope.where(active: ActiveModel::Type::Boolean.new.cast(@params[:active])) if @params[:active].present?
      scope = scope.where(automatic: ActiveModel::Type::Boolean.new.cast(@params[:automatic])) if @params[:automatic].present?
      scope.order(SORTS.fetch(@params[:sort], { created_at: :desc }))
    end
  end
end
