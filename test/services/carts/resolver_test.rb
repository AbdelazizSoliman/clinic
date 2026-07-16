require "test_helper"

class Carts::ResolverTest < ActiveSupport::TestCase
  test "does not create a guest cart on read" do
    session = {}
    assert_nil Carts::Resolver.new(session:).resolve
    assert_empty session
  end

  test "creates and returns an isolated guest cart" do
    session = {}
    cart = Carts::Resolver.new(session:).resolve(create: true)
    assert cart.guest_token.present?
    assert_equal cart, Carts::Resolver.new(session:).resolve
  end

  test "invalid token is replaced only when creation is requested" do
    session = { guest_cart_token: "invalid" }
    assert_nil Carts::Resolver.new(session:).resolve
    replacement = Carts::Resolver.new(session:).resolve(create: true)
    assert_not_equal "invalid", replacement.guest_token
  end

  test "authenticated user receives only their cart" do
    assert_equal carts(:customer_cart), Carts::Resolver.new(session: {}, user: users(:customer)).resolve
  end
end
