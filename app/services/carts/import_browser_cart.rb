module Carts
  class ImportBrowserCart
    def initialize(cart:, items:)
      @cart, @items = cart, items
    end

    def call
      return :already_imported if @cart.browser_imported_at?

      Cart.transaction do
        normalized_items.each do |product_id, quantity|
          product = Product.find_by(id: product_id)
          next unless product

          Carts::SetItemQuantity.new(cart: @cart, product:, quantity:, additive: true).call
        end
        @cart.update!(browser_imported_at: Time.current)
      end
      :imported
    end

    private

    def normalized_items
      Array(@items).each_with_object(Hash.new(0)) do |item, result|
        values = item.respond_to?(:to_h) ? item.to_h.stringify_keys : {}
        id = Integer(values["productId"], exception: false)
        quantity = Integer(values["quantity"], exception: false)
        result[id] += quantity if id&.positive? && quantity&.positive?
      end
    end
  end
end
