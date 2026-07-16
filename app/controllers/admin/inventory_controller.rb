module Admin
  class InventoryController < BaseController
    def index
      @active_products = Product.active.count
      products = Product.includes(:inventory_reservations).to_a
      @out_of_stock = products.count(&:out_of_stock?)
      @low_stock = products.count(&:low_stock?)
      @physical_units = products.sum(&:stock_quantity)
      @reserved_units = InventoryReservation.active.sum(:quantity)
      @available_units = products.sum(&:available_to_sell_quantity)
      @recent_movements = InventoryMovement.includes(:product, :actor).order(created_at: :desc).limit(10)
      @recent_price_changes = ProductPriceChange.includes(:product, :changed_by).order(effective_at: :desc).limit(10)
    end
    def low_stock
      @products = Product.includes(:inventory_reservations, :brand, :category).select { |product| product.low_stock? || product.out_of_stock? }
    end
  end
end
