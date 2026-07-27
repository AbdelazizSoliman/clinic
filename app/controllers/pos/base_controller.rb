module Pos
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_pos!
    layout "staff"

    private

    def authorize_pos!
      head(:not_found) unless current_user&.can_operate_pos?
    end

    def find_sale
      scope = current_user.admin? ? PosSale.all : current_user.pos_sales
      @sale = scope.includes(items: [ :product, :prescription_approved_by, batch_allocations: :inventory_batch ],
        payments: [], cashier_session: :user).find_by!(number: params[:sale_number] || params[:number])
    end
  end
end
