module Pos
  class ProductsController < BaseController
    LIMIT = 30

    def index
      result = ::Search::Products.call(query: params[:q], context: :pos, limit: LIMIT)
      ::Search::RecordEvent.call(result:, actor: current_user)
      render partial: "results", locals: { products: preloaded(result.records), result:,
        sale: PosSale.find_by(number: params[:sale_number]) }
    end

    private

    def preloaded(records)
      ActiveRecord::Associations::Preloader.new(records:, associations: :inventory_batches).call
      records
    end
  end
end
