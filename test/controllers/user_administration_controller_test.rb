require "test_helper"

class UserAdministrationControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  setup do
    PharmacySetting.delete_all
    PharmacySetting.create!
  end

  test "admin manages users while every other role is denied" do
    sign_in users(:admin)
    get admin_users_path
    assert_response :success
    assert_includes response.body, "إدارة المستخدمين"
    sign_out users(:admin)

    %i[customer pharmacist order_manager inventory_manager].each do |role|
      sign_in users(role)
      get admin_users_path
      assert_response :not_found
      sign_out users(role)
    end
  end

  test "admin creates invited staff without accepting protected actor fields" do
    sign_in users(:admin)
    assert_difference([ "User.count", "UserInvitation.count", "UserAuditEvent.count" ], 1) do
      post admin_users_path, params: { user: { first_name: "صيدلي", last_name: "جديد",
        email: "new-staff@example.com", mobile_number: "01033334444", role: "pharmacist",
        active: true, actor_id: users(:customer).id, password: "known-password" } }
    end
    created = User.find_by!(email: "new-staff@example.com")
    assert_not created.active?
    assert created.pharmacist?
    assert_not created.valid_password?("known-password")
    assert_redirected_to admin_user_path(created)
  end

  test "invitation acceptance activates user and invalid token is generic" do
    result = Admin::Users::Invite.new(actor: users(:admin), attributes: { first_name: "مدير", last_name: "طلب",
      email: "accept@example.com", mobile_number: "01044445555", role: "order_manager" }).call
    patch invitation_path(token: result.token), params: { password: "password123", password_confirmation: "password123", role: "admin" }
    assert_redirected_to account_path
    assert result.user.reload.order_manager?

    get invitation_path(token: "invalid-secret")
    assert_response :not_found
    assert_includes response.body, "رابط الدعوة غير صالح"
  end

  test "registration, guest cart and maintenance switches are server enforced" do
    setting = PharmacySetting.first
    setting.update!(customer_registration_enabled: false)
    get new_user_registration_path
    assert_redirected_to new_user_session_path

    setting.update!(customer_registration_enabled: true, guest_cart_enabled: false)
    post cart_items_path, params: { cart_item: { product_id: products(:skin_product).id, quantity: 1 } }
    assert_redirected_to new_user_session_path

    setting.update!(maintenance_mode: true)
    get root_path
    assert_response :service_unavailable
    assert_includes response.body, "نعمل على تحسين الخدمة"
    get rails_health_check_path
    assert_response :success
  end

  test "only admin updates settings and change is audited" do
    sign_in users(:admin)
    get edit_admin_pharmacy_setting_path
    assert_response :success
    assert_difference("SettingsAuditEvent.count") do
      patch admin_pharmacy_setting_path, params: { pharmacy_setting: { pharmacy_name: "صيدليتي الجديدة",
        default_reservation_minutes: 45, lock_version: PharmacySetting.first.lock_version }, reason: "تحديث الهوية" }
    end
    assert_redirected_to edit_admin_pharmacy_setting_path
    sign_out users(:admin)

    sign_in users(:inventory_manager)
    get edit_admin_pharmacy_setting_path
    assert_response :not_found
  end
end
