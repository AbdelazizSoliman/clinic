module Admin
  class SuppliersQuery
    def initialize(relation, params) = (@relation, @params = relation, params)
    def call
      scope = @relation
      if @params[:q].present?
        term = "%#{Supplier.sanitize_sql_like(@params[:q])}%"
        scope = scope.where("name ILIKE :term OR legal_name ILIKE :term OR code ILIKE :term OR contact_person ILIKE :term", term:)
      end
      scope = scope.where(active: @params[:active] == "true") if %w[true false].include?(@params[:active])
      scope.order(active: :desc, name: :asc)
    end
  end
end
