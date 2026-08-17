class RestoreReportExportEventsPosType < ActiveRecord::Migration[8.1]
  CONSTRAINT_NAME = "report_export_events_type_valid".freeze
  VALID_TYPES = %w[sales orders products inventory promotions customers prescriptions
    fulfilments purchasing batches pos].freeze

  def up
    existing = connection.check_constraints(:report_export_events).find { |c| c.name == CONSTRAINT_NAME }
    remove_check_constraint :report_export_events, name: CONSTRAINT_NAME if existing
    add_check_constraint :report_export_events,
      "report_type IN (#{VALID_TYPES.map { |t| connection.quote(t) }.join(',')})",
      name: CONSTRAINT_NAME
  end

  def down
    remove_check_constraint :report_export_events, name: CONSTRAINT_NAME
    add_check_constraint :report_export_events,
      "report_type IN (#{(VALID_TYPES - %w[pos]).map { |t| connection.quote(t) }.join(',')})",
      name: CONSTRAINT_NAME
  end
end
