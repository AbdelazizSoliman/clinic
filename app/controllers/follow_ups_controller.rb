class FollowUpsController < ApplicationController
  before_action :authenticate_user!

  def respond
    order = current_user.orders.find_by!(number: params[:number])
    follow_up = order.follow_ups.find(params[:id])
    result = OrderFollowUps::Respond.new(follow_up:, customer: current_user, body: params[:body], lock_version: params[:lock_version]).call
    redirect_to order_path(order), status: :see_other, flash: { result.success? ? :notice : :alert => result.success? ? "تم إرسال ردك للصيدلي" : result.errors.join("، ") }
  end
end
