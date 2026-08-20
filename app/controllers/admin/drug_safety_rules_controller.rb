module Admin
  # Rule administration is restricted to system administrators. Pharmacists read rule detail
  # from the finding panel but never change central rule definitions during a review.
  class DrugSafetyRulesController < BaseController
    before_action :authorize_rules!
    before_action :set_rule, only: %i[show edit update activate deactivate revise]

    def index
      scope = DrugSafetyRule.includes(conditions: :active_ingredient).ordered
      scope = scope.where(rule_type: params[:rule_type]) if DrugSafetyRule.rule_types.key?(params[:rule_type])
      scope = scope.where(severity: params[:severity]) if DrugSafetyRule.severities.key?(params[:severity])
      scope = scope.where(active: params[:active] == "true") if %w[true false].include?(params[:active])
      @pagy, @rules = pagy(scope, limit: 25)
    end

    def show
      @findings_count = @rule.findings.count
      @versions = DrugSafetyRule.where(code: @rule.code).order(:version)
    end

    def new
      @rule = DrugSafetyRule.new(active: false, severity: :caution, version: 1)
      3.times { @rule.conditions.build }
    end

    def edit
      (3 - @rule.conditions.size).clamp(0, 3).times { @rule.conditions.build }
    end

    def create
      @rule = DrugSafetyRule.new(rule_params.merge(created_by: current_user, active: false))
      if @rule.save
        audit("drug_safety_rule_created")
        redirect_to admin_drug_safety_rule_path(@rule), notice: "تم إنشاء مسودة القاعدة"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @rule.published?
        return redirect_to admin_drug_safety_rule_path(@rule),
          alert: "القاعدة المنشورة غير قابلة للتعديل — أنشئ إصدارًا جديدًا"
      end
      if @rule.update(rule_params)
        audit("drug_safety_rule_updated")
        redirect_to admin_drug_safety_rule_path(@rule), notice: "تم تحديث مسودة القاعدة"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def activate = apply(DrugSafety::RuleLifecycle.activate(rule: @rule, actor: current_user), "تم تفعيل القاعدة")
    def deactivate = apply(DrugSafety::RuleLifecycle.deactivate(rule: @rule, actor: current_user), "تم إيقاف القاعدة")

    def revise
      result = DrugSafety::RuleLifecycle.revise(rule: @rule, actor: current_user)
      redirect_to result.success? ? admin_drug_safety_rule_path(result.rule) : admin_drug_safety_rule_path(@rule),
        status: :see_other,
        flash: { result.success? ? :notice : :alert =>
          result.success? ? "تم إنشاء إصدار جديد كمسودة" : result.errors.join("، ") }
    end

    private

    def authorize_rules!
      head :not_found unless current_user.can_manage_safety_rules?
    end

    def set_rule = @rule = DrugSafetyRule.includes(conditions: :active_ingredient).find(params[:id])

    def apply(result, notice)
      redirect_to admin_drug_safety_rule_path(@rule), status: :see_other,
        flash: { result.success? ? :notice : :alert => result.success? ? notice : result.errors.join("، ") }
    end

    def rule_params
      params.require(:drug_safety_rule).permit(:code, :version, :name, :arabic_label, :description, :rule_type,
        :severity, :blocking, :evidence_note, :internal_notes, :effective_from, :effective_to, :lock_version,
        conditions_attributes: %i[id role condition_type active_ingredient_id state_key numeric_value _destroy])
    end

    def audit(action)
      AdminAuditEvent.create!(actor: current_user, auditable: @rule, action:,
        metadata: { code: @rule.code, version: @rule.version, rule_type: @rule.rule_type, severity: @rule.severity })
    end
  end
end
