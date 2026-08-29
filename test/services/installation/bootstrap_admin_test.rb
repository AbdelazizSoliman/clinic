require "test_helper"

class InstallationBootstrapAdminTest < ActiveSupport::TestCase
  def environment(email: "first-admin@example.test", password: "A-long-random-passphrase-42")
    {
      "ADMIN_ORGANIZATION_CODE" => @organization.code, "ADMIN_BRANCH_CODE" => @branch.code,
      "ADMIN_EMAIL" => email, "ADMIN_PASSWORD" => password, "ADMIN_FIRST_NAME" => "First",
      "ADMIN_LAST_NAME" => "Administrator", "ADMIN_MOBILE" => "+201001112233"
    }
  end

  setup do
    @organization = Organization.create!(code: "BOOTSTRAP_TEST", name: "Bootstrap Test", timezone: "Africa/Cairo", currency: "EGP", locale: "ar")
    @branch = @organization.branches.create!(code: "MAIN", name: "Main", timezone: "Africa/Cairo", default: true)
  end

  test "creates one tenant admin with explicit organization and branch" do
    user = Installation::BootstrapAdmin.call(environment)

    assert user.persisted?
    assert user.admin?
    assert_equal @organization, user.organization
    assert_equal @branch, user.default_branch
    assert UserAuditEvent.unscoped.exists?(user:, action: "bootstrap_admin")
    assert SecurityEvent.unscoped.exists?(user:, event_type: "bootstrap_admin_created")
  end

  test "refuses a second administrator for the tenant" do
    Installation::BootstrapAdmin.call(environment)

    error = assert_raises(Installation::BootstrapAdmin::Refused) do
      Installation::BootstrapAdmin.call(environment(email: "another-admin@example.test"))
    end
    assert_match(/administrator already exists/, error.message)
  end

  test "refuses unsafe example password" do
    error = assert_raises(Installation::BootstrapAdmin::Refused) do
      Installation::BootstrapAdmin.call(environment(password: "change-me-password"))
    end
    assert_equal "ADMIN_PASSWORD is an unsafe example value", error.message
    assert_equal 0, @organization.users.count
  end
end
