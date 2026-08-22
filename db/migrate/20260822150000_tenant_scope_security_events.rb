class TenantScopeSecurityEvents < ActiveRecord::Migration[8.1]
  def up
    organization_id = select_value("SELECT id FROM organizations WHERE code = 'DEFAULT'").to_i
    add_reference :security_events, :organization, null: false, default: organization_id, foreign_key: true, index: true
    add_foreign_key :security_events, :users, column: %i[organization_id user_id],
      primary_key: %i[organization_id id], name: :fk_security_events_user_tenant
    add_foreign_key :security_events, :users, column: %i[organization_id actor_id],
      primary_key: %i[organization_id id], name: :fk_security_events_actor_tenant
  end

  def down
    remove_foreign_key :security_events, name: :fk_security_events_actor_tenant
    remove_foreign_key :security_events, name: :fk_security_events_user_tenant
    remove_reference :security_events, :organization
  end
end
