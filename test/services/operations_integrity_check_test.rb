require "test_helper"

class OperationsIntegrityCheckTest < ActiveSupport::TestCase
  test "returns bounded structured safe findings without repairing" do
    user = users(:pharmacist)
    user.update_columns(otp_secret_ciphertext: nil, otp_enabled_at: nil)
    findings = Operations::IntegrityCheck.new.call
    finding = findings.find { |item| item.code == :privileged_without_two_factor }
    assert finding
    assert_equal :critical, finding.severity
    assert_includes finding.identifiers, user.id.to_s
    assert_operator finding.identifiers.length, :<=, Operations::IntegrityCheck::LIMIT
    assert_nil user.reload.otp_enabled_at
  end
end
