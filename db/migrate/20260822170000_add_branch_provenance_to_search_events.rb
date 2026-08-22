class AddBranchProvenanceToSearchEvents < ActiveRecord::Migration[8.1]
  def up
    add_reference :search_events, :branch, foreign_key: true
    execute <<~SQL.squish
      UPDATE search_events
      SET branch_id = branches.id
      FROM branches
      WHERE branches.organization_id = search_events.organization_id
        AND branches."default" = TRUE
        AND search_events.branch_id IS NULL
    SQL
    execute <<~SQL.squish
      UPDATE search_events
      SET branch_id = (
        SELECT branches.id FROM branches
        WHERE branches.organization_id = search_events.organization_id
        ORDER BY branches.code, branches.id LIMIT 1
      )
      WHERE search_events.branch_id IS NULL
    SQL
    change_column_null :search_events, :branch_id, false
    add_index :search_events, %i[organization_id branch_id created_at], name: "index_search_events_on_org_branch_created"
    add_foreign_key :search_events, :branches, column: %i[organization_id branch_id],
      primary_key: %i[organization_id id], name: "fk_search_events_tenant_branch"
  end

  def down
    remove_foreign_key :search_events, name: "fk_search_events_tenant_branch"
    remove_index :search_events, name: "index_search_events_on_org_branch_created"
    remove_reference :search_events, :branch, foreign_key: true
  end
end
