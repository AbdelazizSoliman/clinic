module Staff
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_staff!
    layout "staff"

    private

    def authorize_staff!
      head :not_found unless current_user&.staff?
    end
  end
end
