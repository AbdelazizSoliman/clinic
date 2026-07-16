class OrdersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_order, only: :show

  def index
    @orders = current_user.orders.includes(:items).order(submitted_at: :desc)
  end

  def show; end

  def create
    result = Orders::CreateFromCart.new(
      user: current_user, cart: current_cart,
      address_id: order_params[:address_id], delivery_method: order_params[:delivery_method],
      payment_method: order_params[:payment_method], submission_token: order_params[:submission_token],
      prescription_files: order_params[:prescription_files], prescription_notes: order_params[:prescription_notes],
      delivery_notes: order_params[:delivery_notes]
    ).call
    if result.success?
      @current_cart = nil
      redirect_to order_path(result.order), notice: "تم استلام طلبك بنجاح برقم #{result.order.number}", status: :see_other
    else
      prepare_checkout(result.errors)
      render "shopping/checkout", status: :unprocessable_entity
    end
  end

  private

  def set_order
    @order = current_user.orders.includes(:items, :order_address, prescription: { images_attachments: :blob }).find_by!(number: params[:number])
  end

  def order_params
    params.require(:order).permit(:address_id, :delivery_method, :payment_method, :submission_token, :prescription_notes, :delivery_notes, prescription_files: [])
  end

  def prepare_checkout(errors)
    @cart = current_cart&.reload
    @addresses = current_user.addresses.where(active: true).order(default: :desc, created_at: :desc)
    @selected_address = @addresses.find_by(id: order_params[:address_id]) || @addresses.find_by(default: true) || @addresses.first
    @readiness = Checkout::Readiness.new(user: current_user, cart: @cart, address: @selected_address, payment_method: order_params[:payment_method]).call
    @cart_issues = errors
    @recommendations = Product.includes(:brand, :category).discounted.available.limit(4)
  end
end
