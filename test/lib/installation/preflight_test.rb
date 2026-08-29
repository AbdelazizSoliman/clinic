require "test_helper"
require Rails.root.join("lib/installation/preflight")

class InstallationPreflightTest < ActiveSupport::TestCase
  def valid_environment
    {
      "RAILS_ENV" => "production", "INSTALLATION_PROFILE" => "buyer_evaluation",
      "DATABASE_URL" => "postgresql://clinic:secret@db/clinic_production",
      "APP_HOST" => "localhost", "ALLOWED_HOSTS" => "localhost,127.0.0.1", "FORCE_SSL" => "false", "APP_PROTOCOL" => "http",
      "WEB_BIND_ADDRESS" => "127.0.0.1",
      "SECRET_KEY_BASE" => "a" * 64, "ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY" => "b" * 32,
      "ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY" => "c" * 32,
      "ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT" => "d" * 32,
      "SECURITY_EVENT_DIGEST_KEY" => "e" * 32, "MAIL_FROM_EMAIL" => "no-reply@example.test",
      "MAIL_FROM_NAME" => "Clinic", "SMTP_ADDRESS" => "mailpit", "SMTP_AUTHENTICATION" => "none",
      "STORAGE_SERVICE" => "local", "MALWARE_SCANNER_ADAPTER" => "clamav", "CLAMAV_HOST" => "clamav"
    }
  end

  def valid_production_environment
    valid_environment.merge("INSTALLATION_PROFILE" => "production", "APP_HOST" => "clinic.example.test",
      "ALLOWED_HOSTS" => "clinic.example.test", "WEB_BIND_ADDRESS" => "0.0.0.0", "FORCE_SSL" => "true",
      "APP_PROTOCOL" => "https", "STORAGE_SERVICE" => "production", "STORAGE_ACCESS_KEY_ID" => "access-key",
      "STORAGE_SECRET_ACCESS_KEY" => "f" * 32, "STORAGE_REGION" => "eu-central-1", "STORAGE_BUCKET" => "clinic-private",
      "SMTP_AUTHENTICATION" => "plain", "SMTP_USERNAME" => "clinic", "SMTP_PASSWORD" => "g" * 32)
  end

  test "accepts supported buyer evaluation environment" do
    results = Installation::Preflight.new(valid_environment).call
    assert_empty results.select { |result| result.status == :fail }
  end

  test "reports missing and unsafe critical configuration without values" do
    environment = valid_environment.merge("DATABASE_URL" => "", "SECRET_KEY_BASE" => "change-me-secret")
    results = Installation::Preflight.new(environment).call

    assert results.any? { |result| result.name == "required variables" && result.status == :fail }
    assert results.any? { |result| result.name == "secrets" && result.status == :fail && result.message.include?("SECRET_KEY_BASE") }
    refute results.map(&:message).any? { |message| message.include?("change-me-secret") }
  end

  test "refuses non-loopback HTTP and unconfigured scanner" do
    environment = valid_environment.merge("APP_HOST" => "demo.example.test", "ALLOWED_HOSTS" => "demo.example.test",
      "MALWARE_SCANNER_ADAPTER" => "unconfigured", "CLAMAV_HOST" => "")
    results = Installation::Preflight.new(environment).call

    assert results.any? { |result| result.name == "evaluation host" && result.status == :fail }
    assert results.any? { |result| result.name == "scanner" && result.status == :fail }
  end

  test "rejects malformed mode values" do
    results = Installation::Preflight.new(valid_environment.merge("FORCE_SSL" => "tru", "STORAGE_SERVICE" => "disk")).call

    assert results.any? { |result| result.name == "configuration values" && result.status == :fail }
  end

  test "evaluation profile activation is exact" do
    %w[buyer-evaluation BUYER_EVALUATION buyer_evaluation\ ].each do |invalid|
      results = Installation::Preflight.new(valid_environment.merge("INSTALLATION_PROFILE" => invalid)).call
      assert results.any? { |result| result.name == "configuration values" && result.status == :fail }, invalid
    end
  end

  test "accepts both loopback evaluation host forms" do
    localhost = Installation::Preflight.new(valid_environment).call
    ip = Installation::Preflight.new(valid_environment.merge("APP_HOST" => "127.0.0.1")).call

    assert_empty localhost.select { |result| result.status == :fail }
    assert_empty ip.select { |result| result.status == :fail }
  end

  test "explicit production and missing profile preserve secure production configuration" do
    explicit = Installation::Preflight.new(valid_production_environment).call
    missing = Installation::Preflight.new(valid_production_environment.except("INSTALLATION_PROFILE")).call
    empty = Installation::Preflight.new(valid_production_environment.merge("INSTALLATION_PROFILE" => "")).call

    assert_empty explicit.select { |result| result.status == :fail }
    assert_empty missing.select { |result| result.status == :fail }
    assert_empty empty.select { |result| result.status == :fail }
  end

  test "rejects public and wildcard evaluation exposure" do
    public_host = Installation::Preflight.new(valid_environment.merge("APP_HOST" => "demo.example.test",
      "ALLOWED_HOSTS" => "demo.example.test")).call
    wildcard_host = Installation::Preflight.new(valid_environment.merge("APP_HOST" => "0.0.0.0",
      "ALLOWED_HOSTS" => "0.0.0.0")).call
    public_bind = Installation::Preflight.new(valid_environment.merge("WEB_BIND_ADDRESS" => "0.0.0.0")).call

    assert public_host.any? { |result| result.name == "evaluation host" && result.status == :fail }
    assert wildcard_host.any? { |result| result.name == "evaluation host" && result.status == :fail }
    assert public_bind.any? { |result| result.name == "evaluation bind" && result.status == :fail }
  end

  test "normal production refuses evaluation-only exceptions" do
    environment = valid_environment.merge("INSTALLATION_PROFILE" => "production", "APP_HOST" => "clinic.example.test",
      "ALLOWED_HOSTS" => "clinic.example.test", "WEB_BIND_ADDRESS" => "0.0.0.0")

    http = Installation::Preflight.new(environment).call
    storage = Installation::Preflight.new(environment.merge("FORCE_SSL" => "true", "APP_PROTOCOL" => "https")).call
    smtp = Installation::Preflight.new(environment.merge("FORCE_SSL" => "true", "APP_PROTOCOL" => "https",
      "STORAGE_SERVICE" => "production")).call

    assert http.any? { |result| result.name == "FORCE_SSL" && result.status == :fail }
    assert storage.any? { |result| result.name == "storage" && result.status == :fail }
    assert smtp.any? { |result| result.name == "mail" && result.status == :fail }
  end
end
