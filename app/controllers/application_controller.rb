class ApplicationController < ActionController::Base
  include Pagy::Method
  include CurrentCart

  before_action :configure_permitted_parameters, if: :devise_controller?

  helper_method :wishlist_item_for, :wishlist_count

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  protected

  def after_sign_in_path_for(resource)
    stored_location_for(resource) || super
  end

  def after_sign_up_path_for(resource)
    stored_location_for(resource) || account_path
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: %i[first_name last_name mobile_number])
  end

  private

  def wishlist_item_for(product)
    return unless user_signed_in?

    current_user.wishlist_items.find { |item| item.product_id == product.id }
  end

  def wishlist_count
    user_signed_in? ? current_user.wishlist_items.size : 0
  end
end
