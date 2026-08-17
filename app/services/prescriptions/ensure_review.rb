module Prescriptions
  class EnsureReview
    def self.call(reviewable)
      new(reviewable).call
    end

    def initialize(reviewable) = @reviewable = reviewable

    def call
      PrescriptionReview.transaction do
        review = PrescriptionReview.find_or_create_by!(reviewable: @reviewable)
        source_items.each do |source|
          next unless source.requires_prescription?
          review.items.find_or_create_by!(reviewable_item: source) do |item|
            item.original_product = source.product
            item.quantity = source.quantity
            item.prescribed_unit_price_cents = prescribed_price(source)
          end
        end
        review
      end
    end

    private

    def source_items
      @reviewable.is_a?(Prescription) ? @reviewable.order.items : @reviewable.items
    end

    def prescribed_price(source)
      if source.is_a?(OrderItem)
        source.final_unit_price_cents || source.unit_price_cents
      else
        source.original_unit_price_cents
      end
    end
  end
end
