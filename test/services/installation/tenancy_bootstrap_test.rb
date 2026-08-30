require "test_helper"

class InstallationTenancyBootstrapTest < ActiveSupport::TestCase
  # Regression coverage for the clean-install defect: `db:prepare` loads db/schema.rb
  # on an empty database, so the DEFAULT organization and MAIN branch inserted by the
  # tenancy migrations never exist and the documented buyer path fails.
  test "creates the organization and branch when neither exists" do
    assert_not Organization.unscoped.exists?(code: "FRESH_INSTALL")

    result = Installation::TenancyBootstrap.call(organization_code: "FRESH_INSTALL", branch_code: "HQ")

    assert result.organization.persisted?
    assert_equal "FRESH_INSTALL", result.organization.code
    assert result.organization.active?
    assert result.branch.persisted?
    assert_equal "HQ", result.branch.code
    assert_equal result.organization.id, result.branch.organization_id
    assert result.branch.default?, "first branch in a new organization must be the default"
  end

  test "is idempotent so re-seeding never duplicates tenancy" do
    first = Installation::TenancyBootstrap.call(organization_code: "FRESH_INSTALL", branch_code: "HQ")
    second = Installation::TenancyBootstrap.call(organization_code: "FRESH_INSTALL", branch_code: "HQ")

    assert_equal first.organization.id, second.organization.id
    assert_equal first.branch.id, second.branch.id
    assert_equal 1, Organization.unscoped.where(code: "FRESH_INSTALL").count
    assert_equal 1, Branch.unscoped.where(organization_id: first.organization.id, code: "HQ").count
  end

  test "normalizes codes and exposes tenancy through Current" do
    result = Installation::TenancyBootstrap.call(organization_code: " fresh_install ", branch_code: " hq ")

    assert_equal "FRESH_INSTALL", result.organization.code
    assert_equal "HQ", result.branch.code
    assert_equal result.organization, Current.organization
    assert_equal result.branch, Current.branch
  end

  test "does not displace an existing default branch" do
    organization = Installation::TenancyBootstrap.call(organization_code: "FRESH_INSTALL", branch_code: "HQ").organization
    second = Installation::TenancyBootstrap.call(organization_code: "FRESH_INSTALL", branch_code: "SATELLITE").branch

    assert_not second.default?
    assert_equal 1, Branch.unscoped.where(organization_id: organization.id, default: true).count
  end

  test "bootstrapped tenancy lets tenant-scoped records resolve an organization" do
    result = Installation::TenancyBootstrap.call(organization_code: "FRESH_INSTALL", branch_code: "HQ")

    category = Category.create!(name: "فئة الاختبار", slug: "install-smoke", position: 0, active: true)

    assert_equal result.organization.id, category.organization_id,
      "tenant-scoped inserts must never fall back to a nil organization_id"
  end
end
