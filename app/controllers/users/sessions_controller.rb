module Users
  class SessionsController < Devise::SessionsController
    def create
      super do |user|
        merged = Carts::MergeGuestCart.new(session:, user:).call
        flash[:notice] = "تم تسجيل الدخول ودمج #{merged} منتج من سلة الضيف" if merged.positive?
      end
    end
  end
end
