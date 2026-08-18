module DrugSafety
  # Pure, side-effect-free rule evaluation: clinical context + rule set -> ordered findings.
  # The same context and rule versions always produce the same findings, in the same order.
  class Evaluate
    Draft = Data.define(:rule, :review_item_id, :related_review_item_id, :severity, :blocking,
      :explanation, :matched_facts, :dedupe_key)

    def self.call(context:, rule_set:) = new(context:, rule_set:).call

    def initialize(context:, rule_set:)
      @context = context
      @rule_set = rule_set
    end

    def call
      drafts = @rule_set.rules.flat_map { |rule| evaluate(rule) }
      drafts.uniq(&:dedupe_key).sort_by { |draft| [ -DrugSafety.severity_rank(draft.severity), draft.dedupe_key ] }
    end

    private

    def evaluate(rule)
      return [] if rule.patient_dependent? && !@context.patient?

      case rule.rule_type
      when "drug_interaction" then interactions(rule)
      when "duplicate_therapy" then duplicates(rule)
      when "allergy" then allergies(rule)
      when "age_restriction" then age_restrictions(rule)
      when *DrugSafety::PATIENT_STATE_RULE_TYPES then patient_states(rule)
      else [] # renal/hepatic/dose rules are not evaluable with the data this application stores.
      end
    end

    # Order-independent: A+B and B+A produce one finding keyed on the sorted line pair.
    def interactions(rule)
      first_id = rule.primary_ingredient_id
      second_id = rule.secondary_ingredient_id
      return [] if first_id.blank? || second_id.blank?

      pairs(@context.lines.select { |line| line.ingredient_ids.include?(first_id) },
        @context.lines.select { |line| line.ingredient_ids.include?(second_id) }).map do |left, right|
        facts = { "ingredient_ids" => [ first_id, second_id ].sort, "product_ids" => [ left.product_id, right.product_id ].sort,
          "ingredients" => [ name_of(first_id), name_of(second_id) ], "products" => [ left.product_name, right.product_name ] }
        draft(rule, left, right, facts,
          "تداخل مسجل محليًا بين #{name_of(first_id)} و#{name_of(second_id)} ضمن #{left.product_name} و#{right.product_name}.")
      end
    end

    # Exact active-ingredient duplication across two dispensing lines. The repository has no
    # therapeutic-class data, so no class-level equivalence is inferred.
    def duplicates(rule)
      @context.lines.combination(2).filter_map do |left, right|
        shared = (left.ingredient_ids & right.ingredient_ids).sort
        next if shared.empty?
        facts = { "ingredient_ids" => shared, "product_ids" => [ left.product_id, right.product_id ].sort,
          "ingredients" => shared.map { |id| name_of(id) }, "products" => [ left.product_name, right.product_name ] }
        draft(rule, left, right, facts,
          "ازدواج في المادة الفعالة #{shared.map { |id| name_of(id) }.join('، ')} بين #{left.product_name} و#{right.product_name}.")
      end
    end

    def allergies(rule)
      allergens = @context.patient.allergy_ingredient_ids
      @context.lines.flat_map do |line|
        (line.ingredient_ids & allergens).sort.map do |ingredient_id|
          facts = { "ingredient_ids" => [ ingredient_id ], "product_ids" => [ line.product_id ],
            "ingredients" => [ name_of(ingredient_id) ], "products" => [ line.product_name ] }
          draft(rule, line, nil, facts,
            "المادة الفعالة #{name_of(ingredient_id)} في #{line.product_name} تطابق حساسية مسجلة لهذا المريض.")
        end
      end
    end

    def age_restrictions(rule)
      age = @context.patient.age_years
      ingredient_id = rule.primary_ingredient_id
      return [] if age.nil? || ingredient_id.blank?

      @context.lines.select { |line| line.ingredient_ids.include?(ingredient_id) }.filter_map do |line|
        bound = age_bound(rule, age)
        next unless bound
        facts = { "ingredient_ids" => [ ingredient_id ], "product_ids" => [ line.product_id ],
          "ingredients" => [ name_of(ingredient_id) ], "products" => [ line.product_name ],
          "age_years" => age, "bound" => bound.first, "bound_years" => bound.last }
        draft(rule, line, nil, facts, "#{bound_sentence(bound, age)} للمادة #{name_of(ingredient_id)} في #{line.product_name}.",
          key_suffix: bound.first)
      end
    end

    def patient_states(rule)
      state = rule.state_key
      ingredient_id = rule.primary_ingredient_id
      return [] if state.blank? || ingredient_id.blank? || !@context.patient.states.include?(state)

      @context.lines.select { |line| line.ingredient_ids.include?(ingredient_id) }.map do |line|
        facts = { "ingredient_ids" => [ ingredient_id ], "product_ids" => [ line.product_id ],
          "ingredients" => [ name_of(ingredient_id) ], "products" => [ line.product_name ], "state" => state }
        draft(rule, line, nil, facts,
          "حالة سريرية مسجلة (#{state_label(state)}) مع #{name_of(ingredient_id)} في #{line.product_name}.")
      end
    end

    def age_bound(rule, age)
      minimum = rule.minimum_age_years
      maximum = rule.maximum_age_years
      return [ "minimum", minimum ] if minimum.present? && age < minimum
      return [ "maximum", maximum ] if maximum.present? && age > maximum
      nil
    end

    def bound_sentence(bound, age)
      if bound.first == "minimum"
        "عمر المريض المسجل #{age} سنة أقل من الحد الأدنى #{bound.last} سنة"
      else
        "عمر المريض المسجل #{age} سنة يتجاوز الحد الأقصى #{bound.last} سنة"
      end
    end

    def state_label(state) = state == "pregnant" ? "حمل" : "رضاعة"

    def pairs(left_lines, right_lines)
      left_lines.product(right_lines).filter_map do |left, right|
        next if left.review_item_id == right.review_item_id
        [ left, right ].sort_by(&:review_item_id)
      end.uniq { |pair| pair.map(&:review_item_id) }
    end

    def draft(rule, line, related, facts, sentence, key_suffix: nil)
      item_ids = [ line.review_item_id, related&.review_item_id ].compact.sort
      key = [ rule.code, "v#{rule.version}", "items:#{item_ids.join('-')}",
        "products:#{Array(facts['product_ids']).join('-')}",
        "ingredients:#{Array(facts['ingredient_ids']).join('-')}", key_suffix ].compact.join(":")
      Draft.new(rule:, review_item_id: item_ids.first, related_review_item_id: item_ids[1],
        severity: rule.severity, blocking: rule.blocking?,
        explanation: "#{rule.arabic_label}: #{sentence} #{DrugSafety::DISCLAIMER}",
        matched_facts: facts, dedupe_key: key)
    end

    def name_of(ingredient_id) = @context.ingredient_names[ingredient_id] || "مادة #{ingredient_id}"
  end
end
