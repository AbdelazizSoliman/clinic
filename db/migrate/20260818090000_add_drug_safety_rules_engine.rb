class AddDrugSafetyRulesEngine < ActiveRecord::Migration[8.1]
  EXPORT_CONSTRAINT = "report_export_events_type_valid".freeze
  EXPORT_TYPES = %w[sales orders products inventory promotions customers prescriptions
    fulfilments purchasing batches pos].freeze

  def up
    create_active_ingredients
    create_patient_clinical_data
    create_rules
    create_evaluations
    extend_report_export_types(EXPORT_TYPES + %w[drug_safety])
  end

  def down
    extend_report_export_types(EXPORT_TYPES)
    drop_table :drug_safety_acknowledgements
    drop_table :drug_safety_findings
    drop_table :drug_safety_evaluations
    drop_table :drug_safety_rule_conditions
    drop_table :drug_safety_rules
    drop_table :patient_allergies
    drop_table :patient_clinical_profiles
    drop_table :product_active_ingredients
    drop_table :active_ingredients
  end

  private

  def create_active_ingredients
    create_table :active_ingredients do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.string :normalized_name, null: false
      t.boolean :active, null: false, default: true
      t.text :notes
      t.timestamps
      t.index :code, unique: true
      t.index :normalized_name, unique: true
      t.index :active
    end

    create_table :product_active_ingredients do |t|
      t.references :product, null: false, foreign_key: true
      t.references :active_ingredient, null: false, foreign_key: true
      t.string :strength
      t.string :unit
      t.boolean :active, null: false, default: true
      t.timestamps
      t.index %i[product_id active_ingredient_id], unique: true, name: "index_product_active_ingredients_unique"
    end
  end

  def create_patient_clinical_data
    create_table :patient_clinical_profiles do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.date :date_of_birth
      t.integer :pregnancy_status, null: false, default: 0
      t.integer :lactation_status, null: false, default: 0
      t.references :recorded_by, null: false, foreign_key: { to_table: :users }
      t.datetime :recorded_at, null: false
      t.text :notes
      t.integer :lock_version, null: false, default: 0
      t.timestamps
      t.check_constraint "pregnancy_status IN (0,1,2)", name: "patient_clinical_profiles_pregnancy_valid"
      t.check_constraint "lactation_status IN (0,1,2)", name: "patient_clinical_profiles_lactation_valid"
      t.check_constraint "date_of_birth IS NULL OR date_of_birth > DATE '1900-01-01'",
        name: "patient_clinical_profiles_dob_plausible"
    end

    create_table :patient_allergies do |t|
      t.references :patient_clinical_profile, null: false, foreign_key: true,
        index: { name: "index_patient_allergies_on_profile" }
      t.references :active_ingredient, null: false, foreign_key: true
      t.integer :severity, null: false, default: 2
      t.references :recorded_by, null: false, foreign_key: { to_table: :users }
      t.datetime :recorded_at, null: false
      t.text :notes
      t.boolean :active, null: false, default: true
      t.timestamps
      t.index %i[patient_clinical_profile_id active_ingredient_id], unique: true,
        name: "index_patient_allergies_unique_ingredient"
      t.check_constraint "severity IN (0,1,2,3)", name: "patient_allergies_severity_valid"
    end
  end

  def create_rules
    create_table :drug_safety_rules do |t|
      t.string :code, null: false
      t.integer :version, null: false, default: 1
      t.string :name, null: false
      t.string :arabic_label, null: false
      t.text :description, null: false
      t.integer :rule_type, null: false
      t.integer :severity, null: false
      t.boolean :active, null: false, default: false
      t.boolean :blocking, null: false, default: false
      t.text :evidence_note
      t.text :internal_notes
      t.datetime :effective_from
      t.datetime :effective_to
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.datetime :activated_at
      t.datetime :retired_at
      t.integer :lock_version, null: false, default: 0
      t.timestamps
      t.index %i[code version], unique: true, name: "index_drug_safety_rules_unique_version"
      t.index :code, unique: true, where: "active", name: "index_drug_safety_rules_single_active_version"
      t.index %i[active rule_type], name: "index_drug_safety_rules_on_active_and_type"
      t.check_constraint "rule_type BETWEEN 0 AND 9", name: "drug_safety_rules_type_valid"
      t.check_constraint "severity IN (0,1,2,3)", name: "drug_safety_rules_severity_valid"
      t.check_constraint "version > 0", name: "drug_safety_rules_version_positive"
      t.check_constraint "NOT blocking OR severity >= 2", name: "drug_safety_rules_blocking_requires_severity"
      t.check_constraint "NOT active OR rule_type <= 6", name: "drug_safety_rules_active_type_supported"
      t.check_constraint "effective_to IS NULL OR effective_from IS NULL OR effective_to > effective_from",
        name: "drug_safety_rules_effective_window_valid"
    end

    create_table :drug_safety_rule_conditions do |t|
      t.references :drug_safety_rule, null: false, foreign_key: true, index: { name: "index_rule_conditions_on_rule" }
      t.integer :role, null: false, default: 0
      t.integer :condition_type, null: false
      t.references :active_ingredient, foreign_key: true, index: { name: "index_rule_conditions_on_ingredient" }
      t.string :state_key
      t.integer :numeric_value
      t.timestamps
      t.index %i[drug_safety_rule_id role condition_type], unique: true, name: "index_rule_conditions_unique_slot"
      t.check_constraint "role IN (0,1)", name: "drug_safety_rule_conditions_role_valid"
      t.check_constraint "condition_type IN (0,1,2,3)", name: "drug_safety_rule_conditions_type_valid"
      t.check_constraint <<~SQL.squish, name: "drug_safety_rule_conditions_payload_valid"
        (condition_type = 0 AND active_ingredient_id IS NOT NULL AND state_key IS NULL AND numeric_value IS NULL)
        OR (condition_type = 1 AND state_key IS NOT NULL AND active_ingredient_id IS NULL AND numeric_value IS NULL)
        OR (condition_type IN (2,3) AND numeric_value IS NOT NULL AND numeric_value >= 0
            AND active_ingredient_id IS NULL AND state_key IS NULL)
      SQL
    end
  end

  def create_evaluations
    create_table :drug_safety_evaluations do |t|
      t.references :prescription_review, null: false, foreign_key: true,
        index: { name: "index_drug_safety_evaluations_on_review" }
      t.integer :sequence, null: false
      t.string :context_digest, null: false
      t.string :ruleset_digest, null: false
      t.integer :trigger, null: false, default: 0
      t.references :actor, foreign_key: { to_table: :users }
      t.datetime :evaluated_at, null: false
      t.integer :findings_count, null: false, default: 0
      t.integer :blocking_count, null: false, default: 0
      t.datetime :superseded_at
      t.timestamps
      t.index %i[prescription_review_id sequence], unique: true, name: "index_drug_safety_evaluations_unique_sequence"
      t.index %i[prescription_review_id superseded_at], name: "index_drug_safety_evaluations_current"
      t.check_constraint "sequence > 0", name: "drug_safety_evaluations_sequence_positive"
      t.check_constraint "trigger BETWEEN 0 AND 7", name: "drug_safety_evaluations_trigger_valid"
      t.check_constraint "findings_count >= 0 AND blocking_count >= 0 AND blocking_count <= findings_count",
        name: "drug_safety_evaluations_counts_valid"
    end

    create_table :drug_safety_findings do |t|
      t.references :drug_safety_evaluation, null: false, foreign_key: true,
        index: { name: "index_drug_safety_findings_on_evaluation" }
      t.references :drug_safety_rule, null: false, foreign_key: true,
        index: { name: "index_drug_safety_findings_on_rule" }
      t.references :prescription_review_item, null: false, foreign_key: true,
        index: { name: "index_drug_safety_findings_on_review_item" }
      t.references :related_review_item, foreign_key: { to_table: :prescription_review_items },
        index: { name: "index_drug_safety_findings_on_related_item" }
      t.references :carried_from, foreign_key: { to_table: :drug_safety_findings },
        index: { name: "index_drug_safety_findings_on_carried_from" }
      t.integer :severity, null: false
      t.boolean :blocking, null: false, default: false
      t.integer :status, null: false, default: 0
      t.text :explanation, null: false
      t.jsonb :rule_snapshot, null: false, default: {}
      t.jsonb :matched_facts, null: false, default: {}
      t.string :dedupe_key, null: false
      t.datetime :resolved_at
      t.references :resolved_by, foreign_key: { to_table: :users }
      t.integer :lock_version, null: false, default: 0
      t.timestamps
      t.index %i[drug_safety_evaluation_id dedupe_key], unique: true, name: "index_drug_safety_findings_unique_key"
      t.index %i[status blocking], name: "index_drug_safety_findings_on_status_and_blocking"
      t.index %i[severity created_at], name: "index_drug_safety_findings_on_severity_and_created_at"
      t.check_constraint "severity IN (0,1,2,3)", name: "drug_safety_findings_severity_valid"
      t.check_constraint "status IN (0,1,2,3)", name: "drug_safety_findings_status_valid"
      t.check_constraint "NOT blocking OR severity >= 2", name: "drug_safety_findings_blocking_requires_severity"
      t.check_constraint <<~SQL.squish, name: "drug_safety_findings_resolution_consistent"
        (status = 0 AND resolved_at IS NULL AND resolved_by_id IS NULL)
        OR (status IN (1,2) AND resolved_at IS NOT NULL AND resolved_by_id IS NOT NULL)
        OR (status = 3 AND resolved_at IS NOT NULL AND resolved_by_id IS NULL)
      SQL
    end

    create_table :drug_safety_acknowledgements do |t|
      t.references :drug_safety_finding, null: false, foreign_key: true,
        index: { name: "index_drug_safety_acknowledgements_on_finding" }
      t.references :pharmacist, null: false, foreign_key: { to_table: :users },
        index: { name: "index_drug_safety_acknowledgements_on_pharmacist" }
      t.integer :action, null: false
      t.text :reason
      t.datetime :created_at, null: false
      t.index %i[drug_safety_finding_id created_at], name: "index_drug_safety_acknowledgements_timeline"
      t.check_constraint "action IN (0,1)", name: "drug_safety_acknowledgements_action_valid"
      t.check_constraint "action = 0 OR reason IS NOT NULL", name: "drug_safety_acknowledgements_override_reason"
    end
  end

  def extend_report_export_types(types)
    existing = connection.check_constraints(:report_export_events).find { |constraint| constraint.name == EXPORT_CONSTRAINT }
    remove_check_constraint :report_export_events, name: EXPORT_CONSTRAINT if existing
    add_check_constraint :report_export_events,
      "report_type IN (#{types.map { |type| connection.quote(type) }.join(',')})", name: EXPORT_CONSTRAINT
  end
end
