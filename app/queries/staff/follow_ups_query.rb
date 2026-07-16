module Staff
  class FollowUpsQuery
    def initialize(relation, params)
      @relation, @params = relation, params
    end

    def call
      scope = @relation
      scope = scope.where(status: @params[:status]) if OrderFollowUp.statuses.key?(@params[:status])
      scope = scope.where(kind: @params[:kind]) if OrderFollowUp.kinds.key?(@params[:kind])
      if @params[:q].present?
        term = "%#{OrderFollowUp.sanitize_sql_like(@params[:q])}%"
        scope = scope.joins(order: :user).where("orders.number ILIKE :term OR users.email ILIKE :term OR users.first_name ILIKE :term OR users.last_name ILIKE :term", term:)
      end
      scope.order(due_at: :asc, created_at: :asc)
    end
  end
end
