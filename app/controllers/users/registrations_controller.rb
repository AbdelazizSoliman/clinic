module Users
  class RegistrationsController < Devise::RegistrationsController
    def create
      super do |user|
        next unless user.persisted?

        user.update_column(:role, User.roles[:customer]) unless user.customer?
        merged = Carts::MergeGuestCart.new(session:, user:).call
        flash[:notice] = "مرحبًا بك! تم حفظ سلة التسوق في حسابك" if merged.positive?
      end
    end
  end
end
