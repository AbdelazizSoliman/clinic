module Staff
  class OrdersQuery
    SORTS = { "oldest" => { submitted_at: :asc }, "newest" => { submitted_at: :desc }, "number" => { number: :asc }, "priority" => { status: :asc, submitted_at: :asc } }.freeze

    def initialize(relation, params)
      @relation, @params = relation, params
    end

    def call
      scope = @relation
      scope = apply_search(scope)
      scope = scope.where(status: @params[:status]) if Order.statuses.key?(@params[:status])
      scope = scope.where(prescription_required: true) if @params[:prescription] == "true"
      scope = scope.joins(:prescription).where(prescriptions: { status: @params[:prescription_status] }) if Prescription.statuses.key?(@params[:prescription_status])
      scope = scope.where(payment_method: @params[:payment_method]) if Order.payment_methods.key?(@params[:payment_method])
      scope = scope.where(payment_status: @params[:payment_status]) if Order.payment_statuses.key?(@params[:payment_status])
      scope = scope.where(submitted_at: parsed_date(@params[:date_from])..) if parsed_date(@params[:date_from])
      scope = scope.where(submitted_at: ..parsed_date(@params[:date_to]).end_of_day) if parsed_date(@params[:date_to])
      scope.order(SORTS.fetch(@params[:sort], SORTS["oldest"]))
    end

    private

    def apply_search(scope)
      return scope if @params[:q].blank?

      term = "%#{Order.sanitize_sql_like(@params[:q])}%"
      scope.where("orders.number ILIKE :term OR orders.customer_first_name ILIKE :term OR orders.customer_last_name ILIKE :term OR orders.customer_email ILIKE :term", term: term)
    end

    def parsed_date(value)
      Date.iso8601(value) if value.present?
    rescue Date::Error
      nil
    end
  end
end
