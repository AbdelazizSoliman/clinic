class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  default_scope do
    if column_names.include?("organization_id")
      organization_id = Current.organization&.id || Organization.default_organization&.id
      relation = where(organization_id:)
      if Current.branch_scope && column_names.include?("branch_id")
        relation.where(branch_id: Current.branch_scope.id)
      else
        relation
      end
    else
      where({})
    end
  end

  before_validation :assign_current_organization, if: -> { has_attribute?(:organization_id) && organization_id.nil? }
  validate :tenant_associations_match, if: -> { has_attribute?(:organization_id) && organization_id.present? }

  private

  def assign_current_organization
    self.organization_id = Current.organization&.id || Organization.default_organization&.id
  end

  def tenant_associations_match
    self.class.reflect_on_all_associations(:belongs_to).each do |reflection|
      next if reflection.name == :organization
      associated = public_send(reflection.name)
      next unless associated&.respond_to?(:organization_id) && associated.organization_id.present?
      errors.add(reflection.name, "يجب أن ينتمي إلى نفس المؤسسة") if associated.organization_id != organization_id
    end
  end
end
