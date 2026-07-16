module Carts
  class MergeGuestCart
    def initialize(session:, user:)
      @session, @user = session, user
    end

    def call
      token = @session[Carts::Resolver::SESSION_KEY]
      return 0 if token.blank?

      merged_count = 0
      Cart.transaction do
        guest = Cart.active.lock.find_by(guest_token: token)
        return 0 unless guest

        target = @user.carts.active.first_or_create!(currency: "EGP")
        guest.items.includes(:product).each do |source|
          next unless source.product.active? && source.product.available?

          result = Carts::SetItemQuantity.new(cart: target, product: source.product, quantity: source.quantity, additive: true).call
          merged_count += 1 if result.success?
        end
        guest.update!(status: :merged)
        guest.items.destroy_all
        @session.delete(Carts::Resolver::SESSION_KEY)
      end
      merged_count
    end
  end
end
