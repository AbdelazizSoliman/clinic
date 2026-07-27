module Pos
  class ProductsController < BaseController
    def index
      query = params[:q].to_s.strip
      @products = Product.active.where(
        "barcode = :exact OR sku = :exact OR name ILIKE :term OR short_description ILIKE :term",
        exact: query, term: "%#{Product.sanitize_sql_like(query)}%"
      ).order(Arel.sql("CASE WHEN barcode = #{Product.connection.quote(query)} THEN 0 WHEN sku = #{Product.connection.quote(query)} THEN 1 ELSE 2 END"), :name).limit(30)
      render partial: "results", locals: { products: @products, sale: PosSale.find_by(number: params[:sale_number]) }
    end
  end
end
