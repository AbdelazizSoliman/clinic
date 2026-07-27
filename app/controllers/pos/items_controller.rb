module Pos
  class ItemsController < BaseController
    before_action :find_sale

    def create
      product = find_product
      result = Cart.new(sale: @sale, actor: current_user).add(product:, quantity: params[:quantity].presence || 1)
      redirect_to pos_sale_path(@sale), result.success? ? { notice: "تمت إضافة المنتج" } : { alert: result.errors.join("، ") }
    end

    def update
      item = @sale.items.find(params[:id])
      result = Cart.new(sale: @sale, actor: current_user).update(item:, quantity: params[:quantity])
      redirect_to pos_sale_path(@sale), result.success? ? {} : { alert: result.errors.join("، ") }
    end

    def destroy
      item = @sale.items.find(params[:id])
      result = Cart.new(sale: @sale, actor: current_user).remove(item:)
      redirect_to pos_sale_path(@sale), result.success? ? { notice: "تم حذف البند" } : { alert: result.errors.join("، ") }
    end

    private

    def find_product
      if params[:barcode].present?
        Product.active.find_by(barcode: params[:barcode].to_s.strip)
      else
        Product.active.find_by(id: params[:product_id])
      end
    end
  end
end
