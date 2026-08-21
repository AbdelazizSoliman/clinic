class BenefitsController < ApplicationController
  before_action :authenticate_user!
  def show
    return head :not_found unless current_user.customer?
    @loyalty_account = current_user.loyalty_account
    @wallet_account = current_user.wallet_account
    @loyalty_entries = @loyalty_account&.ledger_entries&.order(occurred_at: :desc)&.limit(100) || LoyaltyLedgerEntry.none
    @wallet_entries = @wallet_account&.ledger_entries&.order(occurred_at: :desc)&.limit(100) || WalletLedgerEntry.none
  end
end
