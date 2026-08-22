module Returns
  class Create
    include Support

    def initialize(source:, actor:, items:, customer_notes: nil)
      @source, @actor, @specs, @customer_notes = source, actor, Array(items), customer_notes
    end

    def call
      return failure(nil, "لا يمكن إنشاء مرتجع عبر مؤسسات مختلفة") unless Operations::TenantGuard.same_organization?(@source, @actor)
      return failure(nil, "المعاملة الأصلية غير مؤهلة للمرتجع") unless eligible_source?
      return failure(nil, "غير مصرح بإنشاء المرتجع") unless authorized?
      request = nil
      ReturnRequest.transaction do
        @source.lock!
        request = ReturnRequest.create!(number: number, source: @source, requested_by: @actor,
          status: :submitted, submitted_at: Time.current, customer_notes: @customer_notes)
        @specs.each { |spec| create_item!(request, spec.to_h.symbolize_keys) }
        raise ActiveRecord::RecordInvalid, request if request.items.empty?
        audit(@actor, request, "return_created", source: @source.class.name, source_number: @source.number)
        audit(@actor, request, "return_submitted")
      end
      success(request)
    rescue ActiveRecord::RecordInvalid => error
      failure(request || error.record, error.record.errors.full_messages.presence || [ "يلزم اختيار بند واحد على الأقل" ])
    rescue ActiveRecord::RecordNotUnique
      failure(request, "تعارضت كمية المرتجع مع طلب آخر؛ أعد المحاولة")
    end

    private

    def eligible_source? = @source.is_a?(Order) ? @source.delivered? : @source.is_a?(PosSale) && @source.completed?
    def authorized? = @actor && ((@actor.customer? && @source.is_a?(Order) && @source.user_id == @actor.id) || @actor.can_initiate_returns?)
    def number = "RT-#{Time.current.strftime('%Y%m%d')}-#{SecureRandom.hex(4).upcase}"

    def create_item!(request, spec)
      quantity = spec[:quantity].to_i
      return unless quantity.positive?
      line = source_items.lock.find(spec.fetch(:source_item_id))
      already = ReturnItem.joins(:return_request).where(source_item: line)
        .where.not(return_requests: { status: [ ReturnRequest.statuses[:rejected], ReturnRequest.statuses[:cancelled] ] }).sum(:requested_quantity)
      raise ActiveRecord::RecordInvalid, request if quantity > line.quantity - already
      net_line = allocated_net_for(line)
      refundable = (net_line * quantity) / line.quantity
      returned_before = ReturnItem.where(source_item: line).joins(:return_request)
        .where(return_requests: { status: %i[received refunded closed] }).sum(:received_quantity)
      refundable = net_line - ReturnItem.where(source_item: line).joins(:return_request)
        .where(return_requests: { status: %i[received refunded closed] }).sum(:refundable_amount_cents) if returned_before + quantity == line.quantity
      effective = line.try(:prescription_review_item)&.effective_product || line.product
      request.items.create!(source_item: line, original_product: line.product, dispensed_product: effective,
        requested_quantity: quantity, unit_price_cents: line.try(:final_unit_price_cents) || line.unit_price_cents,
        allocated_discount_cents: [ line.unit_price_cents.to_i * quantity - refundable, 0 ].max,
        tax_cents: 0, refundable_amount_cents: refundable, reason: spec[:reason], reason_notes: spec[:reason_notes],
        condition: spec[:condition].presence || :unknown,
        pharmacist_inspection_required: line.requires_prescription? || effective&.pharmacist_review_required?)
    end

    def source_items = @source.items

    # Largest-remainder allocation: source net merchandise total is distributed by original
    # gross line value, ties by stable line id. Delivery is deliberately excluded.
    def allocated_net_for(target)
      lines = source_items.order(:id).to_a
      gross = lines.to_h { |line| [ line.id, line.unit_price_cents.to_i * line.quantity ] }
      pool = if @source.is_a?(Order)
        @source.subtotal_cents - @source.discount_cents - @source.loyalty_discount_cents + @source.prescription_adjustment_cents
      else
        @source.total_cents - @source.tax_cents
      end
      total_gross = gross.values.sum
      return 0 if total_gross.zero?
      floors = gross.transform_values { |value| pool * value / total_gross }
      remainder = pool - floors.values.sum
      ranked = lines.sort_by { |line| [ -(pool * gross[line.id] % total_gross), line.id ] }
      remainder.times { |index| floors[ranked[index].id] += 1 }
      floors.fetch(target.id)
    end
  end
end
