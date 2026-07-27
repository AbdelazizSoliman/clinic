module Pos
  class DashboardController < BaseController
    def index
      @session = current_user.cashier_sessions.open.first
      @sale = @session&.pos_sales&.draft&.order(:created_at)&.first
      @recent_sales = (current_user.admin? ? PosSale.all : current_user.pos_sales).completed.order(completed_at: :desc).limit(8)
    end
  end
end
