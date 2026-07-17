module DemoGuidance
  class ScenarioResolver
    def initialize(user:, routes:)
      @user = user
      @routes = routes
    end

    def path(key)
      __send__(key)
    end

    private

    def catalog = @routes.products_path
    def cart = @routes.cart_path
    def checkout = @routes.checkout_path
    def customer_orders = @routes.orders_path

    def customer_delivered_order
      order = @user.orders.find_by(number: "DEMO-DELIVERED-OLD") if @user&.customer?
      order ? @routes.order_path(order) : customer_orders
    end

    def prescription_product
      product = Product.publicly_available.find_by(slug: "demo-rx-tablets-a")
      product ? @routes.product_path(product) : @routes.products_path(prescription: "true")
    end

    def pharmacist_queue = allowed?(:can_review_prescriptions?) && @routes.staff_prescriptions_path

    def prescription_under_review
      return unless allowed?(:can_review_prescriptions?)

      prescription = prescription_for("DEMO-PRESCRIPTION-REVIEW")
      prescription ? @routes.staff_prescription_path(prescription) : @routes.staff_prescriptions_path(q: "DEMO-PRESCRIPTION-REVIEW")
    end

    def prescription_examples
      allowed?(:can_review_prescriptions?) && @routes.staff_prescriptions_path(status: "approved")
    end

    def prescription_orders
      allowed?(:can_review_prescriptions?) && @routes.staff_orders_path(prescription: "true")
    end

    def operations_confirmed = allowed?(:can_operate_orders?) && staff_order("DEMO-CONFIRMED", "confirmed")
    def operations_preparing = allowed?(:can_operate_orders?) && staff_order("DEMO-PREPARING", "preparing")
    def operations_ready = allowed?(:can_operate_orders?) && staff_order("DEMO-READY", "ready_for_delivery")
    def operations_dispatched = allowed?(:can_manage_delivery?) && fulfilment("DEMO-OUT-FOR-DELIVERY", "dispatched")
    def operations_cancelled = allowed?(:can_operate_orders?) && staff_order("DEMO-CANCELLED", "cancelled")

    def inventory_dashboard = allowed?(:can_manage_inventory?) && @routes.admin_root_path
    def inventory_low = allowed?(:can_manage_inventory?) && @routes.admin_low_stock_inventory_path
    def inventory_movements = allowed?(:can_manage_inventory?) && @routes.admin_inventory_adjustments_path
    def inventory_reports = allowed?(:can_view_inventory_reports?) && @routes.admin_reports_inventory_index_path(preset: "last_30_days")

    def admin_users = allowed?(:can_manage_users?) && @routes.admin_users_path(q: "@example.test")
    def admin_settings = allowed?(:can_manage_application_settings?) && @routes.edit_admin_pharmacy_setting_path

    def admin_promotion
      return unless allowed?(:can_manage_promotions?)

      promotion = Promotion.find_by(internal_name: "demo:active-cart")
      promotion ? @routes.admin_promotion_path(promotion) : @routes.admin_promotions_path
    end

    def admin_delivery = allowed?(:can_manage_delivery?) && @routes.staff_delivery_zones_path
    def admin_reports = allowed?(:can_view_business_reports?) && @routes.admin_reports_root_path(preset: "last_30_days")
    def admin_security = @user&.admin? && @routes.admin_security_path

    def allowed?(capability)
      @user&.public_send(capability)
    end

    def prescription_for(number)
      Prescription.joins(:order).find_by(orders: { number: })
    end

    def staff_order(number, fallback_status)
      order = Order.find_by(number:)
      order ? @routes.staff_order_path(order) : @routes.staff_orders_path(status: fallback_status)
    end

    def fulfilment(number, fallback_status)
      record = Fulfilment.joins(:order).find_by(orders: { number: })
      record ? @routes.staff_fulfilment_path(record) : @routes.staff_fulfilments_path(status: fallback_status)
    end
  end
end
