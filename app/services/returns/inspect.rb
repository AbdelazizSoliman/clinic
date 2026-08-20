module Returns
  class Inspect
    include Support
    def initialize(item:, actor:, condition:, disposition:, notes: nil)
      @item, @actor, @condition, @disposition, @notes = item, actor, condition, disposition, notes
    end
    def call
      return failure(@item, "الفحص الدوائي متاح للصيدلي فقط") unless @actor&.can_inspect_returns?
      return success(@item) if @item.inspected_at? && @item.condition == @condition.to_s && @item.disposition == @disposition.to_s
      @item.with_lock do
        raise ActiveRecord::RecordInvalid, @item unless @item.return_request.approved?
        @item.update!(condition: @condition, disposition: @disposition, inspected_by: @actor,
          inspected_at: Time.current, inspection_notes: @notes)
        audit(@actor, @item.return_request, "return_item_inspected", return_item_id: @item.id)
      end
      success(@item)
    rescue ActiveRecord::RecordInvalid => error
      failure(@item, error.record.errors.full_messages)
    end
  end
end
