module Admin
  class UsersQuery
    SORTS = { "name" => "first_name ASC, last_name ASC", "newest" => "created_at DESC", "updated" => "updated_at DESC", "last_sign_in" => "last_sign_in_at DESC NULLS LAST", "role" => "role ASC, first_name ASC" }.freeze

    def initialize(relation = User.all, params = {})
      @relation, @params = relation, params
    end

    def call
      scope = @relation
      if @params[:q].present?
        escaped = ActiveRecord::Base.sanitize_sql_like(@params[:q].to_s.strip)
        scope = scope.where("first_name ILIKE :q OR last_name ILIKE :q OR email ILIKE :q OR mobile_number ILIKE :q", q: "%#{escaped}%")
      end
      scope = scope.where(role: @params[:role]) if @params[:role].to_s.in?(User.roles.keys)
      scope = scope.where(active: ActiveModel::Type::Boolean.new.cast(@params[:active])) if @params[:active].present?
      scope = scope.where(last_sign_in_at: nil) if @params[:never_signed_in] == "true"
      scope = scope.where(created_at: Date.iso8601(@params[:from]).beginning_of_day..) if @params[:from].present?
      scope = scope.where(created_at: ...Date.iso8601(@params[:to]).next_day.beginning_of_day) if @params[:to].present?
      scope.order(Arel.sql(SORTS.fetch(@params[:sort].to_s, SORTS["newest"])))
    rescue Date::Error
      scope.order(created_at: :desc)
    end
  end
end
