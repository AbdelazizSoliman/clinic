class AddIntegrationAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :integration_audit_events do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :api_client, foreign_key: true
      t.references :actor, foreign_key: { to_table: :users }
      t.references :auditable, polymorphic: true, null: false
      t.string :action, null: false
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :integration_audit_events, %i[organization_id created_at]
  end
end
