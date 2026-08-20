module DrugSafety
  # Deterministic snapshot of the structured clinical facts relevant to one prescription review.
  # It reads only local application data — no external lookup, no free-text interpretation.
  class Context
    Line = Data.define(:review_item_id, :product_id, :product_name, :ingredient_ids)
    Patient = Data.define(:user_id, :age_years, :states, :allergy_ingredient_ids)

    attr_reader :review, :evaluated_at, :lines, :patient

    def self.build(review, evaluated_at: Time.current) = new(review, evaluated_at:).tap(&:load)

    def initialize(review, evaluated_at: Time.current)
      @review = review
      @evaluated_at = evaluated_at
      @lines = []
      @patient = nil
    end

    def load
      @lines = build_lines
      @patient = build_patient
      self
    end

    def patient? = @patient.present?
    def line_for(review_item_id) = lines.find { |line| line.review_item_id == review_item_id }

    def ingredient_names
      @ingredient_names ||= ActiveIngredient.where(id: lines.flat_map(&:ingredient_ids).uniq |
        Array(patient&.allergy_ingredient_ids)).pluck(:id, :name).to_h
    end

    def digest
      Digest::SHA256.hexdigest(canonical_facts.to_json)
    end

    def canonical_facts
      { "lines" => lines.map { |line| line.to_h.transform_keys(&:to_s) },
        "patient" => patient && patient.to_h.transform_keys(&:to_s) }
    end

    private

    # Rejected lines leave the clinical context: nothing is dispensed for them.
    def build_lines
      items = review.items.includes(:original_product, dispensed_product: {}).reject(&:rejected?).sort_by(&:id)
      products = Product.where(id: items.map { |item| item.candidate_product&.id }.compact)
        .includes(product_active_ingredients: :active_ingredient).index_by(&:id)
      items.filter_map do |item|
        product = products[item.candidate_product&.id]
        next unless product
        Line.new(review_item_id: item.id, product_id: product.id, product_name: product.name,
          ingredient_ids: product.clinical_ingredient_ids)
      end
    end

    def build_patient
      user = review.patient
      return nil unless user
      profile = PatientClinicalProfile.includes(allergies: :active_ingredient).find_by(user:)
      return nil unless profile
      Patient.new(user_id: user.id, age_years: profile.age_years_on(evaluated_at.to_date),
        states: profile.state_flags.select { |_key, value| value }.keys.sort,
        allergy_ingredient_ids: profile.allergies.select { |allergy| allergy.active? && allergy.active_ingredient.active? }
          .map(&:active_ingredient_id).sort)
    end
  end
end
