module Installation
  class BootstrapAdmin
    class Refused < StandardError; end

    REQUIRED = %w[ADMIN_EMAIL ADMIN_PASSWORD ADMIN_FIRST_NAME ADMIN_LAST_NAME ADMIN_MOBILE].freeze
    UNSAFE_PASSWORDS = %w[password password123 admin123456 changeme change-me replace-me].freeze

    def self.call(environment = ENV.to_h) = new(environment).call

    def initialize(environment)
      @environment = environment
    end

    def call
      missing = REQUIRED.select { |name| value(name).blank? }
      refuse("missing required variables: #{missing.join(', ')}") if missing.any?
      refuse("ADMIN_PASSWORD must contain at least 12 characters") if value("ADMIN_PASSWORD").length < 12
      refuse("ADMIN_PASSWORD is an unsafe example value") if unsafe_password?

      organization = Organization.active.find_by(code: value("ADMIN_ORGANIZATION_CODE", "DEFAULT").upcase)
      refuse("ADMIN_ORGANIZATION_CODE does not identify an active organization") unless organization
      refuse("an administrator already exists for organization #{organization.code}") if organization.users.admin.exists?

      branch = organization.branches.active.find_by(code: value("ADMIN_BRANCH_CODE", "MAIN").upcase)
      refuse("ADMIN_BRANCH_CODE does not identify an active branch in organization #{organization.code}") unless branch

      email = value("ADMIN_EMAIL").downcase
      refuse("a user with ADMIN_EMAIL already exists") if User.exists?(email:)

      user = nil
      ApplicationRecord.transaction do
        Current.organization = organization
        Current.branch = branch
        user = organization.users.build(email:, password: value("ADMIN_PASSWORD"),
          first_name: value("ADMIN_FIRST_NAME"), last_name: value("ADMIN_LAST_NAME"),
          mobile_number: value("ADMIN_MOBILE"), role: :admin, active: true, default_branch: branch)
        refuse(user.errors.full_messages.join("; ")) unless user.valid?
        user.save!
        UserAuditEvent.create!(user:, action: "bootstrap_admin", reason: "Explicit installation bootstrap")
        SecurityEvent.record("bootstrap_admin_created", user:, metadata: { role: user.role, action: "bootstrap" })
      ensure
        Current.reset
      end
      user
    rescue ActiveRecord::RecordNotUnique
      refuse("administrator creation conflicted with an existing account; inspect users and retry")
    end

    private

    def value(name, default = nil) = @environment.fetch(name, default).to_s.strip

    def unsafe_password?
      normalized = value("ADMIN_PASSWORD").downcase
      UNSAFE_PASSWORDS.include?(normalized) || normalized.include?("replace-me") || normalized.include?("change-me")
    end

    def refuse(message) = raise Refused, message
  end
end
