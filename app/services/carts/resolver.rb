module Carts
  class Resolver
    SESSION_KEY = :guest_cart_token

    def initialize(session:, user: nil)
      @session = session
      @user = user
    end

    def resolve(create: false)
      return user_cart(create:) if @user

      guest_cart(create:)
    end

    private

    def user_cart(create:)
      scope = @user.carts.active
      create ? scope.first_or_create!(currency: "EGP") : scope.first
    end

    def guest_cart(create:)
      token = @session[SESSION_KEY]
      cart = Cart.active.find_by(guest_token: token) if token.present?
      return cart if cart
      return unless create

      @session[SESSION_KEY] = SecureRandom.urlsafe_base64(32)
      Cart.create!(guest_token: @session[SESSION_KEY], currency: "EGP")
    end
  end
end
