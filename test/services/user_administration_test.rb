require "test_helper"

class UserAdministrationTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "capabilities remain admin only and role numbers are preserved" do
    assert_equal({ "customer" => 0, "admin" => 1, "pharmacist" => 2, "order_manager" => 3, "inventory_manager" => 4 }, User.roles)
    assert users(:admin).can_manage_users?
    assert users(:admin).can_manage_application_settings?
    assert_not users(:inventory_manager).can_manage_users?
  end

  test "invitation stores digest, queues mail and accepts once" do
    result = nil
    assert_enqueued_with(job: InvitationDeliveryJob) do
      result = Admin::Users::Invite.new(actor: users(:admin), attributes: {
        first_name: "مريم", last_name: "حسن", email: "invited@example.com",
        mobile_number: "01022223333", role: "pharmacist"
      }).call
    end

    assert result.success?
    assert_not result.user.active?
    assert_not_equal result.token, result.invitation.token_digest
    assert_equal UserInvitation.digest(result.token), result.invitation.token_digest

    accepted = Invitations::Accept.new(token: result.token, password: "password123", password_confirmation: "password123").call
    assert accepted.success?
    assert accepted.user.reload.active?
    assert result.invitation.reload.accepted?
    assert_not Invitations::Accept.new(token: result.token, password: "another123", password_confirmation: "another123").call.success?
    assert accepted.user.pharmacist?
  end

  test "expired and revoked invitations are rejected" do
    invitation = UserInvitation.create!(user: users(:inactive), invited_by: users(:admin),
      token_digest: UserInvitation.digest("expired"), sent_at: 4.days.ago, expires_at: 1.hour.ago)
    assert invitation.expired?
    assert_not Invitations::Accept.new(token: "expired", password: "password123", password_confirmation: "password123").call.success?
  end

  test "final active admin cannot be demoted or deactivated" do
    result = Admin::Users::Update.new(actor: users(:admin), user: users(:admin),
      attributes: { active: false }, reason: "اختبار الحماية").call
    assert_not result.success?
    assert users(:admin).reload.active?

    other = User.create!(email: "second-admin@example.com", password: "password123", first_name: "مدير",
      last_name: "ثان", mobile_number: "01011112222", role: :admin, active: true)
    result = Admin::Users::Update.new(actor: users(:admin), user: users(:admin),
      attributes: { role: "inventory_manager" }, reason: "نقل المسؤولية").call
    assert result.success?
    assert users(:admin).reload.inventory_manager?
    assert_equal "role_changed", users(:admin).user_audit_events.last.action
    assert other.admin?
  end

  test "settings singleton validates ranges and audits update" do
    setting = PharmacySetting.create!
    assert_not PharmacySetting.new(default_reservation_minutes: 1).valid?
    result = Settings::Update.new(actor: users(:admin), setting:,
      attributes: { pharmacy_name: "صيدلية الاختبار", guest_cart_enabled: false }, reason: "تجربة").call
    assert result.success?
    assert_equal "صيدلية الاختبار", PharmacySetting.current.pharmacy_name
    assert_equal 1, SettingsAuditEvent.count
    assert_not Settings::Update.new(actor: users(:inventory_manager), setting:, attributes: { maintenance_mode: true }, reason: "").call.success?
  end

  test "audit events are append only" do
    event = UserAuditEvent.create!(user: users(:customer), actor: users(:admin), action: "activated")
    assert_not event.update(reason: "changed")
    assert_not event.destroy
  end
end
