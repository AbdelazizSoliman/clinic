class DemoController < ApplicationController
  before_action :authenticate_user!
  before_action :require_demo_mode

  def show
    resolver = DemoGuidance::ScenarioResolver.new(user: current_user, routes: self)
    @journey_catalog = DemoGuidance::JourneyCatalog.new(user: current_user, resolver:)
    @journeys = @journey_catalog.call
    @current_journey = @journeys.find { |journey| journey.role.to_s == current_user.role }
    @current_demo_account = DemoData::Accounts::DEFINITIONS.values.find { |account| account[:email] == current_user.email }
  end

  private

  def require_demo_mode
    head :not_found unless demo_mode?
  end
end
