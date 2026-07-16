class OrdersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_order, only: %i[show cancel]

  def index
    @orders = current_user.orders.includes(:items).order(submitted_at: :desc)
  end

  def show; end

  def cancel
    result = Orders::Cancel.new(order: @order, actor: current_user, reason: params[:reason], source: "customer", lock_version: params[:lock_version]).call
    redirect_to order_path(@order), status: :see_other, flash: { result.success? ? :notice : :alert => result.success? ? "تم إلغاء الطلب وتحرير المخزون المحجوز" : result.errors.join("، ") }
  end

  def create
    result = Orders::CreateFromCart.new(
      user: current_user, cart: current_cart,
      address_id: order_params[:address_id], delivery_method: order_params[:delivery_method],
      payment_method: order_params[:payment_method], submission_token: order_params[:submission_token],
      delivery_slot_id: order_params[:delivery_slot_id],
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
    @order = current_user.orders.includes(:items, :order_address, :events, follow_ups: :messages, prescription: { images_attachments: :blob }).find_by!(number: params[:number])
  end

  def order_params
    params.require(:order).permit(:address_id, :delivery_method, :delivery_slot_id, :payment_method, :submission_token, :prescription_notes, :delivery_notes, prescription_files: [])
  end

  def prepare_checkout(errors)
    @cart = current_cart&.reload
    @addresses = current_user.addresses.where(active: true).order(default: :desc, created_at: :desc)
    @selected_address = @addresses.find_by(id: order_params[:address_id]) || @addresses.find_by(default: true) || @addresses.first
    @delivery_zone = Delivery::ZoneMatcher.call(@selected_address).zone if @selected_address
    @delivery_methods = @delivery_zone&.delivery_methods&.active&.ordered || DeliveryMethod.none
    @selected_delivery_method = order_params[:delivery_method]
    @delivery_slots = @delivery_zone&.delivery_slots&.available&.order(:delivery_date, :starts_at) || DeliverySlot.none
    @selected_delivery_slot = @delivery_slots.find_by(id: order_params[:delivery_slot_id])
    @readiness = Checkout::Readiness.new(user: current_user, cart: @cart, address: @selected_address,
      payment_method: order_params[:payment_method], delivery_method: @selected_delivery_method,
      delivery_slot: @selected_delivery_slot).call
    @cart_issues = errors
    @recommendations = Product.includes(:brand, :category).discounted.available.limit(4)
  end
end
