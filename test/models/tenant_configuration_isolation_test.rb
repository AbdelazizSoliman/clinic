require "test_helper"

class TenantConfigurationIsolationTest < ActiveSupport::TestCase
  test "settings singleton and reusable configuration keys are isolated per organization" do
    first = organizations(:default)
    second = Organization.create!(code: "CONFIG-B", name: "Configuration B", active: true,
      timezone: "Africa/Cairo", currency: "EGP", locale: "ar")

    first_setting = Current.set(organization: first) do
      PharmacySetting.first_or_create!(organization_id: first.id)
    end
    second_setting = Current.set(organization: second) do
      PharmacySetting.create!(first_setting.attributes.except("id", "organization_id", "created_at", "updated_at")
        .merge(organization_id: second.id, pharmacy_name: "صيدلية أخرى"))
    end

    assert_equal first_setting.id, Current.set(organization: first) { PharmacySetting.current.id }
    assert_equal second_setting.id, Current.set(organization: second) { PharmacySetting.current.id }

    Current.set(organization: first) { SearchSynonym.create!(term: "اختبار", expansion: "بديل", active: true) }
    Current.set(organization: second) { SearchSynonym.create!(term: "اختبار", expansion: "بديل", active: true) }
    assert_equal 1, Current.set(organization: first) { SearchSynonym.where(term: "اختبار").count }
    assert_equal 1, Current.set(organization: second) { SearchSynonym.where(term: "اختبار").count }
  ensure
    Current.reset
  end
end
