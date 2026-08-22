module Api
  module V1
    class ProductsController < BaseController
      before_action -> { require_scope!("catalog:read") }
      def index
        products = paginate(Product.order(:id))
        render json: { data: products.map { |p| serialize(p) }, meta: { page:, per_page: page_size } }
      end
      def show
        product = Product.find(params[:id])
        render json: { data: serialize(product) }
      rescue ActiveRecord::RecordNotFound
        render_error("not_found", "المنتج غير موجود", :not_found)
      end
      private
      def serialize(product) = { id: product.id, sku: product.sku, name: product.name, price_cents: (product.price * 100).round, active: product.active? }
    end
  end
end
