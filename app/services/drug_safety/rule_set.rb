module DrugSafety
  # The ordered, versioned set of locally configured rules in force at a point in time.
  class RuleSet
    attr_reader :rules, :evaluated_at

    def self.effective_at(time) = new(time)

    def initialize(evaluated_at)
      @evaluated_at = evaluated_at
      @rules = DrugSafetyRule.evaluable_at(evaluated_at).includes(conditions: :active_ingredient).ordered.to_a
    end

    def of_type(rule_type) = rules.select { |rule| rule.rule_type == rule_type.to_s }

    def digest
      Digest::SHA256.hexdigest(rules.map { |rule| "#{rule.code}:#{rule.version}:#{rule.updated_at.to_i}" }.join("|"))
    end
  end
end
