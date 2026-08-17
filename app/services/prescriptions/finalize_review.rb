module Prescriptions
  class FinalizeReview
    def self.call(review, actor:)
      new(review, actor).call
    end

    def initialize(review, actor) = (@review, @actor = review, actor)

    def call
      return unless @review.all_items_decided?
      if @review.online?
        finalize_online
      else
        @review.update!(status: :completed, completed_at: Time.current)
      end
    end

    private

    def finalize_online
      prescription = @review.reviewable
      order = prescription.order
      items = @review.items.to_a
      any_rejected = items.any?(&:rejected?)
      any_dispensable = order.items.where(requires_prescription: false).exists? || items.any?(&:dispensable?)
      status = if !any_dispensable
        :rejected
      elsif any_rejected
        :partially_approved
      else
        :approved
      end
      prescription.update!(status:, reviewed_by: @actor, reviewed_at: Time.current,
        rejection_reason: status == :rejected ? "رُفضت جميع البنود المقيدة" : nil,
        customer_message: status == :partially_approved ? "تم اعتماد بعض البنود ورفض بنود أخرى" : nil)
      adjustment = items.sum(&:line_adjustment_cents)
      base_total = order.subtotal_cents - order.discount_cents + order.delivery_fee_cents -
        order.delivery_discount_cents
      order.update!(status: any_dispensable ? :submitted : :rejected,
        prescription_adjustment_cents: adjustment, total_cents: base_total + adjustment)
      @review.update!(status: :completed, completed_at: Time.current)
      order.events.create!(actor: @actor, event_type: "prescription_line_review_completed",
        from_status: "pending_prescription", to_status: order.status, customer_visible: true,
        metadata: { approved: items.count(&:approved?), substituted: items.count(&:substituted?),
          rejected: items.count(&:rejected?) })
      order.events.create!(actor: @actor,
        event_type: status == :rejected ? "prescription_rejected" : "prescription_approved",
        from_status: "pending_prescription", to_status: order.status, customer_visible: true)
      if any_dispensable
        Inventory::ExtendReservations.new(order:, actor: @actor).call
        notify("prescription_approved", "اكتملت مراجعة بنود الروشتة",
          "راجع البنود المعتمدة والمستبدلة والمرفوضة للطلب #{order.number}")
      else
        Promotions::ReleaseRedemptions.call(order)
        notify("prescription_rejected", "تعذر صرف بنود الروشتة",
          "رُفضت البنود المقيدة للطلب #{order.number}")
      end
    end

    def notify(kind, title, body)
      prescription = @review.reviewable
      Notifications::Create.call(user: prescription.user, actor: @actor, notifiable: prescription.order,
        kind:, title:, body:, key: "line-review-#{@review.id}-#{kind}")
    end
  end
end
