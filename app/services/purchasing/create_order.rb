module Purchasing
  class CreateOrder
    include Support
    Result = Data.define(:success?, :purchase_order, :errors)

    def initialize(actor:, supplier:, attributes: {})
      @actor, @supplier, @attributes = actor, supplier, attributes
    end

    def call
      return failure(nil, "غير مصرح بإدارة المشتريات") unless @actor&.can_manage_purchasing?
      order = nil
      PurchaseOrder.transaction do
        order = PurchaseOrder.create!(@attributes.merge(supplier: @supplier, created_by: @actor,
          number: "PENDING-#{SecureRandom.uuid}", status: :draft, currency: "EGP"))
        order.update!(number: "PO-#{order.created_at.in_time_zone('Africa/Cairo').strftime('%Y%m%d')}-#{order.id.to_s.rjust(6, '0')}")
        event(order, "created", to: "draft")
        audit(order, "purchase_order_created", number: order.number, supplier_code: @supplier.code)
      end
      Result.new(success?: true, purchase_order: order, errors: [])
    rescue ActiveRecord::RecordInvalid => error
      failure(order, error.record.errors.full_messages.join("، "))
    end

    private

    def failure(order, message) = Result.new(success?: false, purchase_order: order, errors: [ message ])
  end
end
