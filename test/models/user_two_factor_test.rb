require "test_helper"

class UserTwoFactorTest < ActiveSupport::TestCase
  test "totp timestep cannot be replayed and recovery code is single use" do
    user = users(:admin)
    secret = ROTP::Base32.random
    user.update!(otp_secret: secret, otp_enabled_at: Time.current)
    code = ROTP::TOTP.new(secret).now
    assert user.verify_totp(code)
    assert_not user.verify_totp(code)

    recovery = user.regenerate_recovery_codes!.first
    assert user.consume_recovery_code(recovery)
    assert_not user.consume_recovery_code(recovery)
  end
end
