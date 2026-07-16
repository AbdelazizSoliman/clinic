module Admin
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_inventory!
    layout "admin"

    private

    def authorize_inventory!
      head :not_found unless current_user&.can_manage_catalog?
    end
  end
end
