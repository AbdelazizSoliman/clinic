module DrugSafety
  # Rule administration is data-driven only: activation, retirement and revision. No rule ever
  # carries executable code, SQL or user-supplied expressions.
  class RuleLifecycle
    Result = Data.define(:success?, :rule, :errors)

    def self.activate(rule:, actor:) = new(rule:, actor:).activate
    def self.deactivate(rule:, actor:) = new(rule:, actor:).deactivate
    def self.revise(rule:, actor:) = new(rule:, actor:).revise

    def initialize(rule:, actor:)
      @rule = rule
      @actor = actor
    end

    def activate
      return unauthorized unless authorized?
      return failure("نوع القاعدة غير مدعوم للتقييم في هذه المرحلة") unless @rule.supported?
      return failure("القاعدة تحتاج شروطًا صحيحة قبل التفعيل") unless @rule.valid?

      DrugSafetyRule.transaction do
        superseded = DrugSafetyRule.active.where(code: @rule.code).where.not(id: @rule.id).to_a
        superseded.each { |other| other.update!(active: false, retired_at: Time.current) }
        @rule.update!(active: true, activated_at: @rule.activated_at || Time.current, retired_at: nil)
        audit("drug_safety_rule_activated", superseded: superseded.map(&:identity))
      end
      success
    rescue ActiveRecord::RecordInvalid => error
      failure(error.record.errors.full_messages)
    end

    def deactivate
      return unauthorized unless authorized?
      @rule.update!(active: false, retired_at: Time.current)
      audit("drug_safety_rule_deactivated")
      success
    rescue ActiveRecord::RecordInvalid => error
      failure(error.record.errors.full_messages)
    end

    # Clinical content of a published rule is immutable. A revision is a brand new version so
    # historical findings keep the exact wording and severity they were produced with.
    def revise
      return unauthorized unless authorized?

      draft = nil
      DrugSafetyRule.transaction do
        next_version = DrugSafetyRule.where(code: @rule.code).maximum(:version).to_i + 1
        draft = DrugSafetyRule.new(@rule.attributes.symbolize_keys
          .slice(:code, :name, :arabic_label, :description, :rule_type, :severity, :blocking,
            :evidence_note, :internal_notes, :effective_from, :effective_to)
          .merge(version: next_version, active: false, activated_at: nil, retired_at: nil, created_by: @actor))
        @rule.conditions.each do |condition|
          draft.conditions.build(condition.attributes.symbolize_keys
            .slice(:role, :condition_type, :active_ingredient_id, :state_key, :numeric_value))
        end
        draft.save!
        AdminAuditEvent.create!(actor: @actor, auditable: draft, action: "drug_safety_rule_revised",
          metadata: { code: draft.code, from_version: @rule.version, to_version: draft.version })
      end
      Result.new(success?: true, rule: draft, errors: [])
    rescue ActiveRecord::RecordInvalid => error
      failure(error.record.errors.full_messages)
    end

    private

    def authorized? = @actor&.can_manage_safety_rules?
    def unauthorized = failure("إدارة قواعد السلامة متاحة لمدير النظام فقط")

    def audit(action, metadata = {})
      AdminAuditEvent.create!(actor: @actor, auditable: @rule, action:,
        metadata: metadata.merge(code: @rule.code, version: @rule.version, rule_type: @rule.rule_type,
          severity: @rule.severity, blocking: @rule.blocking))
    end

    def success = Result.new(success?: true, rule: @rule, errors: [])
    def failure(messages) = Result.new(success?: false, rule: @rule, errors: Array(messages))
  end
end
