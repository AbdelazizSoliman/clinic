module Prescriptions
  class DecideLine
    Result = Data.define(:success?, :item, :errors)
    DECISIONS = %w[approved rejected substituted].freeze

    def initialize(item:, actor:, decision:, reason:, notes: nil, substitute_product: nil,
      physician_instruction_reference: nil, lock_version: nil)
      @item, @actor, @decision = item, actor, decision.to_s
      @reason, @notes = reason.to_s.squish, notes.to_s.squish.presence
      @substitute = substitute_product
      @physician_reference = physician_instruction_reference.to_s.squish.presence
      @lock_version = lock_version
    end

    def call
      return failure("القرار السريري متاح للصيدلي فقط") unless @actor&.can_make_prescription_decisions?
      return failure("قرار البند غير صحيح") unless DECISIONS.include?(@decision)
      return failure("سبب القرار مطلوب") if @reason.blank?
      errors = preflight_errors
      return failure(errors) if errors.any?

      transaction_errors = []
      PrescriptionReviewItem.transaction do
        review = @item.prescription_review
        review.lock!
        @item.lock!
        raise ActiveRecord::StaleObjectError.new(@item, "review") if @lock_version && @item.lock_version != @lock_version.to_i
        unless @item.pending? || @item.under_review?
          transaction_errors << "تم اتخاذ قرار نهائي لهذا البند"
          raise ActiveRecord::Rollback
        end
        review.update!(status: :under_review, started_at: Time.current, started_by: @actor) if review.pending?
        review.reviewable.update!(status: :under_review) if review.online? && review.reviewable.submitted?
        product = effective_product
        price = product && (product.price * 100).round
        from = @item.status
        @item.assign_attributes(status: @decision, dispensed_product: product,
          dispensed_unit_price_cents: price, reviewed_by: @actor, reviewed_at: Time.current,
          reason: @reason, pharmacist_notes: @notes,
          physician_instruction_reference: @physician_reference)
        @item.save!
        create_substitution! if @decision == "substituted"
        allocate_online_inventory!(transaction_errors) if review.online? && @item.dispensable?
        record_online_rejection! if review.online? && @item.rejected?
        raise ActiveRecord::Rollback if transaction_errors.any?
        @item.decisions.create!(actor: @actor, from_status: from, to_status: @decision,
          reason: @reason, notes: @notes, metadata: decision_metadata)
        audit("prescription_line_#{@decision}")
        FinalizeReview.call(review, actor: @actor) if review.reload.all_items_decided?
        Pos::Recalculate.call(review.reviewable) if review.pos?
      end
      return failure(transaction_errors) if transaction_errors.any?
      success
    rescue ActiveRecord::StaleObjectError
      failure("تم تحديث البند بواسطة مستخدم آخر؛ أعد تحميل الصفحة")
    rescue ActiveRecord::RecordInvalid => error
      failure(error.record.errors.full_messages)
    end

    private

    def preflight_errors
      return [] unless @decision == "substituted"
      errors = []
      errors << "اختر المنتج البديل" unless @substitute
      errors << "المنتج البديل يجب أن يكون مختلفًا" if @substitute&.id == @item.original_product_id
      errors << "المنتج البديل غير نشط" unless @substitute&.active?
      errors << "المنتج البديل يجب أن يتطلب روشتة" unless @substitute&.requires_prescription?
      errors << "المنتج البديل غير متاح من تشغيلات صالحة" unless @substitute&.available?
      errors
    end

    def effective_product
      return nil if @decision == "rejected"
      @decision == "substituted" ? @substitute : @item.original_product
    end

    def create_substitution!
      @item.create_therapeutic_substitution!(original_product: @item.original_product,
        substitute_product: @substitute, pharmacist: @actor, substituted_at: Time.current,
        reason: @reason, physician_instruction_reference: @physician_reference)
    end

    def allocate_online_inventory!(errors)
      source = @item.reviewable_item
      existing = source.inventory_reservation
      if existing&.active? && existing.product_id != effective_product.id
        Inventory::ReleaseReservation.call(existing)
        existing = nil
      end
      return if existing&.active?
      reservation = source.order.inventory_reservations.create!(order_item: source,
        product: effective_product, quantity: source.quantity, status: :active,
        expires_at: Inventory::ReservationExpiryPolicy.expires_at_for(source.order))
      result = Inventory::AllocateFefo.new(reservation:).call
      errors.concat(result.errors) unless result.success?
    end

    def record_online_rejection!
      source = @item.reviewable_item
      return if source.inventory_reservations.released.exists?
      source.order.inventory_reservations.create!(order_item: source,
        product: @item.original_product, quantity: source.quantity, status: :released,
        released_at: Time.current)
    end

    def decision_metadata
      return {} unless @decision == "substituted"
      { original_product_id: @item.original_product_id, substitute_product_id: @substitute.id }
    end

    def audit(action)
      AdminAuditEvent.create!(actor: @actor, auditable: @item.prescription_review, action:,
        metadata: { review_item_id: @item.id, original_product_id: @item.original_product_id,
          dispensed_product_id: @item.dispensed_product_id })
    end
    def success = Result.new(success?: true, item: @item, errors: [])
    def failure(messages) = Result.new(success?: false, item: @item, errors: Array(messages))
  end
end
