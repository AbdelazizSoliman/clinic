module Staff
  class DeliveryBaseController < BaseController
    before_action :authorize_delivery!
    private
    def authorize_delivery!
      head :not_found unless current_user.can_manage_delivery?
    end
  end
end
