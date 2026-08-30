module Installation
  # Guarantees the organization and branch that every tenant-scoped record depends on.
  #
  # The tenancy migrations insert DEFAULT/MAIN with raw SQL, but `db:prepare` loads
  # db/schema.rb on an empty database and never runs migration bodies. Without these
  # rows `Organization.default_organization` is nil, `ApplicationRecord` assigns a nil
  # organization_id to every tenant-scoped insert, and `users:create_admin` has no
  # organization to attach the first administrator to. Seeding calls this first so the
  # supported installation path works on a genuinely empty database.
  class TenancyBootstrap
    Result = Data.define(:organization, :branch)

    DEFAULT_ORGANIZATION_CODE = "DEFAULT".freeze
    DEFAULT_BRANCH_CODE = "MAIN".freeze
    TIMEZONE = "Africa/Cairo".freeze

    def self.call(...) = new(...).call

    def initialize(organization_code: DEFAULT_ORGANIZATION_CODE, branch_code: DEFAULT_BRANCH_CODE)
      @organization_code = organization_code.to_s.strip.upcase
      @branch_code = branch_code.to_s.strip.upcase
    end

    def call
      organization = find_or_create_organization
      branch = find_or_create_branch(organization)
      Current.organization = organization
      Current.branch = branch
      Result.new(organization:, branch:)
    end

    private

    def find_or_create_organization
      Organization.unscoped.find_or_create_by!(code: @organization_code) do |organization|
        organization.name = "Default Pharmacy Organization"
        organization.active = true
        organization.timezone = TIMEZONE
        organization.currency = "EGP"
        organization.locale = "ar"
      end
    end

    def find_or_create_branch(organization)
      Branch.unscoped.find_or_create_by!(organization_id: organization.id, code: @branch_code) do |branch|
        branch.name = "Main Branch"
        branch.arabic_name = "الفرع الرئيسي"
        branch.active = true
        branch.default = !Branch.unscoped.exists?(organization_id: organization.id, default: true)
        branch.timezone = TIMEZONE
      end
    end
  end
end
