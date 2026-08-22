module Operations
  module TenantGuard
    module_function

    def same_organization?(*records)
      ids = records.compact.filter_map { |record| record.try(:organization_id) }.uniq
      ids.one? && (Current.organization.nil? || ids.first == Current.organization.id)
    end
  end
end
