module Pos
  class SessionsController < BaseController
    def index
      @sessions = (current_user.admin? ? CashierSession.all : current_user.cashier_sessions).includes(:user).order(opened_at: :desc).limit(100)
    end

    def show
      @session = session_scope.includes(pos_sales: :payments).find_by!(identifier: params[:identifier])
    end

    def create
      result = OpenSession.new(actor: current_user, opening_cash_cents: params[:opening_cash_cents]).call
      redirect_to(result.success? ? pos_root_path : pos_sessions_path,
        result.success? ? { notice: "تم فتح جلسة الصندوق" } : { alert: result.errors.join("، ") })
    end

    def close
      @session = session_scope.find_by!(identifier: params[:identifier])
      result = CloseSession.new(session: @session, actor: current_user,
        counted_cash_cents: params[:closing_cash_counted_cents], notes: params[:notes],
        lock_version: params[:lock_version]).call
      redirect_to pos_session_path(@session.identifier),
        result.success? ? { notice: "تم إغلاق الجلسة وتسوية الصندوق" } : { alert: result.errors.join("، ") }
    end

    private

    def session_scope = current_user.admin? ? CashierSession.all : current_user.cashier_sessions
  end
end
