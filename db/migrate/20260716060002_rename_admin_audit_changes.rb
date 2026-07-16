class RenameAdminAuditChanges < ActiveRecord::Migration[7.2]
  def change
    rename_column :admin_audit_events, :changes, :change_data
  end
end
