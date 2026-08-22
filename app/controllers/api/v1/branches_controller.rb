module Api
  module V1
    class BranchesController < BaseController
      before_action -> { require_scope!("inventory:read") }
      def index
        render json: { data: Branch.active.order(:code).map { |b| { id: b.id, code: b.code, name: b.name, active: b.active? } } }
      end
    end
  end
end
