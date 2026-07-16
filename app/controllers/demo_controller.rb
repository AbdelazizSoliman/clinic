class DemoController < ApplicationController
  before_action :authenticate_user!
  before_action :require_demo_mode

  def show
    @demo_accounts = DemoData::Accounts::DEFINITIONS.values_at(:admin, :pharmacist, :order_manager, :inventory_manager, :customer)
  end

  private

  def require_demo_mode
    head :not_found unless demo_mode?
  end
end
