module Pos
  class SalesController < BaseController
    before_action :find_sale, only: %i[show complete void]

    def index
      @sales = (current_user.admin? ? PosSale.all : current_user.pos_sales).includes(:cashier).order(created_at: :desc).limit(100)
    end

    def new
      session = current_user.cashier_sessions.open.first
      return redirect_to(pos_root_path, alert: "افتح جلسة صندوق أولًا") unless session
      existing = session.pos_sales.draft.order(:created_at).first
      return redirect_to(pos_sale_path(existing)) if existing
      @sale = session.pos_sales.build(cashier: current_user, number: NumberGenerator.sale)
    end

    def create
      session = current_user.cashier_sessions.open.first
      return redirect_to(pos_root_path, alert: "افتح جلسة صندوق أولًا") unless session
      sale = session.pos_sales.create!(cashier: current_user, number: NumberGenerator.sale)
      AdminAuditEvent.create!(actor: current_user, auditable: sale, action: "pos_sale_created")
      redirect_to pos_sale_path(sale)
    rescue ActiveRecord::RecordInvalid => error
      redirect_to pos_root_path, alert: error.record.errors.full_messages.join("، ")
    end

    def show
      @products = Product.active.includes(:inventory_batches).order(:name).limit(20)
      @idempotency_key = @sale.completion_idempotency_key || SecureRandom.uuid
    end

    def complete
      result = Complete.new(sale: @sale, actor: current_user,
        idempotency_key: params[:idempotency_key],
        payments: payment_specs).call
      redirect_to pos_sale_path(result.record || @sale),
        result.success? ? { notice: "اكتملت عملية البيع" } : { alert: result.errors.join("، ") }
    end

    def void
      result = VoidSale.new(sale: @sale, actor: current_user, reason: params[:reason]).call
      redirect_to pos_sale_path(@sale),
        result.success? ? { notice: "تم إلغاء المسودة" } : { alert: result.errors.join("، ") }
    end

    private

    def payment_specs
      [ { payment_method: params[:payment_method], amount_cents: params[:amount_cents],
        tendered_cents: params[:tendered_cents], external_reference: params[:external_reference] } ]
    end
  end
end
