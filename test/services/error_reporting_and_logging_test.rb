require "test_helper"
require Rails.root.join("lib/structured_log_formatter")

class ErrorReportingAndLoggingTest < ActiveSupport::TestCase
  test "error context and JSON logs allowlist safe fields" do
    context = Errors::Reporter.safe_context(request_id: "request-1", actor_role: "admin",
      password: "secret", otp: "123456", email: "person@example.com", medical_note: "private")
    assert_equal "request-1", context[:request_id]
    assert_equal "admin", context[:actor_role]
    assert_nil context[:password]
    assert_nil context[:otp]
    assert_nil context[:email]

    output = StructuredLogFormatter.new.call("INFO", Time.utc(2026), nil,
      { event_type: "test", request_id: "request-1", token: "secret", medical_note: "private" })
    parsed = JSON.parse(output)
    assert_equal "test", parsed["event_type"]
    assert_nil parsed["token"]
    assert_nil parsed["medical_note"]
  end
end
