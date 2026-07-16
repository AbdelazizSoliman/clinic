module CurrentCart
  extend ActiveSupport::Concern

  included { helper_method :current_cart, :cart_quantity_for }

  private

  def current_cart
    return @current_cart if defined?(@current_cart)

    @current_cart = Carts::Resolver.new(session:, user: current_user).resolve
  end

  def resolve_cart!
    @current_cart = Carts::Resolver.new(session:, user: current_user).resolve(create: true)
  end

  def cart_quantity_for(product)
    current_cart&.items&.find { |item| item.product_id == product.id }&.quantity.to_i
  end
end
