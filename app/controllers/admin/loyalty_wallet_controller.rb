module Admin
  class LoyaltyWalletController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_admin!
    layout "admin"

    def show
      @rules = LoyaltyRule.order(:rule_type, :code)
      @customer = User.customer.find_by(id: params[:customer_id])
    end

    def create_rule
      rule = LoyaltyRule.new(rule_params)
      rule.save!
      AdminAuditEvent.create!(actor: current_user, auditable: rule, action: "loyalty_rule_created")
      redirect_to admin_loyalty_wallet_path, notice: "تم إنشاء القاعدة", status: :see_other
    rescue ActiveRecord::RecordInvalid => error
      redirect_to admin_loyalty_wallet_path, alert: error.record.errors.full_messages.join("، "), status: :see_other
    end

    def adjust_loyalty
      customer = User.customer.find(params[:customer_id])
      result = Loyalty::Adjust.new(customer:, actor: current_user, points: params[:points],
        direction: params[:direction], reason: params[:reason], idempotency_key: params[:idempotency_key]).call
      redirect_result(result, customer)
    end

    def adjust_wallet
      customer = User.customer.find(params[:customer_id])
      result = Wallet::Adjust.new(customer:, actor: current_user, amount_cents: params[:amount_cents],
        direction: params[:direction], reason: params[:reason], idempotency_key: params[:idempotency_key]).call
      redirect_result(result, customer)
    end

    private
    def authorize_admin!
      head(:not_found) unless current_user&.can_manage_loyalty_wallet?
    end
    def rule_params
      params.require(:loyalty_rule).permit(:code, :name, :rule_type, :active, :points_awarded,
        :spend_threshold_cents, :redemption_points, :redemption_value_cents, :minimum_redemption_points,
        :maximum_redemption_points, :minimum_eligible_spend_cents, :expiration_days, :effective_from, :effective_to)
    end
    def redirect_result(result, customer)
      redirect_to admin_loyalty_wallet_path(customer_id: customer.id), status: :see_other,
        flash: { result.success? ? :notice : :alert => result.success? ? "تم تسجيل قيد تعويضي" : result.errors.join("، ") }
    end
  end
end
