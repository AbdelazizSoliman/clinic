require "uri"

module Installation
  class Preflight
    Result = Data.define(:name, :status, :message)
    PLACEHOLDER = /(change[-_ ]?me|replace[-_ ]?me|example[-_ ]?secret|your[-_ ]|<.+>)/i
    SECRET_NAMES = %w[SECRET_KEY_BASE RAILS_MASTER_KEY POSTGRES_PASSWORD
      ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY
      ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT SECURITY_EVENT_DIGEST_KEY].freeze

    def initialize(environment = ENV.to_h)
      @environment = environment
      @results = []
    end

    def call
      required_variables
      configuration_values
      database_url
      secrets
      host_and_ssl
      storage
      mail
      scanner
      @results
    end

    private

    def profile = @environment["INSTALLATION_PROFILE"].to_s
    def evaluation? = profile == "buyer_evaluation"
    def env(name) = @environment[name].to_s.strip
    def pass(name, message) = @results << Result.new(name:, status: :pass, message:)
    def fail(name, message) = @results << Result.new(name:, status: :fail, message:)

    def required_variables
      names = %w[RAILS_ENV DATABASE_URL APP_HOST ALLOWED_HOSTS MAIL_FROM_EMAIL MAIL_FROM_NAME
        SMTP_ADDRESS ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY
        ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT SECURITY_EVENT_DIGEST_KEY]
      names << "SECRET_KEY_BASE" if env("SECRET_KEY_BASE").empty? && env("RAILS_MASTER_KEY").empty?
      missing = names.select { |name| env(name).empty? }
      missing.empty? ? pass("required variables", "all required variables are present") :
        fail("required variables", "set: #{missing.join(', ')}")
      fail("RAILS_ENV", "supported Compose path requires RAILS_ENV=production") unless env("RAILS_ENV") == "production"
    end

    def configuration_values
      errors = []
      errors << "INSTALLATION_PROFILE" unless %w[production buyer_evaluation].include?(profile) || profile.empty?
      errors << "FORCE_SSL" unless %w[true false].include?(env("FORCE_SSL"))
      errors << "STORAGE_SERVICE" unless %w[production local].include?(env("STORAGE_SERVICE"))
      errors << "SMTP_AUTHENTICATION" unless %w[plain login cram_md5 none].include?(env("SMTP_AUTHENTICATION"))
      errors.empty? ? pass("configuration values", "profile, SSL, storage, and SMTP modes are recognized") :
        fail("configuration values", "correct unsupported values: #{errors.join(', ')}")
    end

    def database_url
      uri = URI.parse(env("DATABASE_URL"))
      if %w[postgres postgresql].include?(uri.scheme) && !uri.host.to_s.empty? && uri.path.to_s.length > 1
        pass("DATABASE_URL", "PostgreSQL URL has a host and database name")
      else
        fail("DATABASE_URL", "use a postgresql:// URL with host and database name")
      end
    rescue URI::InvalidURIError
      fail("DATABASE_URL", "value is not a valid URL")
    end

    def secrets
      provided = SECRET_NAMES.filter_map { |name| [name, env(name)] unless env(name).empty? }
      unsafe = provided.filter_map { |name, value| name if value.match?(PLACEHOLDER) || value.length < 24 }
      unsafe.empty? ? pass("secrets", "configured secrets are non-placeholder values with reasonable length") :
        fail("secrets", "replace unsafe or short values: #{unsafe.join(', ')}")
    end

    def host_and_ssl
      hosts = env("ALLOWED_HOSTS").split(",").map(&:strip)
      hosts.include?(env("APP_HOST")) ? pass("hosts", "APP_HOST is allowed") : fail("hosts", "include APP_HOST in ALLOWED_HOSTS")
      if evaluation? && !%w[localhost 127.0.0.1].include?(env("APP_HOST"))
        fail("evaluation host", "buyer evaluation requires APP_HOST=localhost or 127.0.0.1")
      elsif evaluation? && !%w[localhost 127.0.0.1].include?(env("WEB_BIND_ADDRESS"))
        fail("evaluation bind", "buyer evaluation requires a loopback WEB_BIND_ADDRESS")
      elsif env("FORCE_SSL") == "false" && !evaluation?
        fail("FORCE_SSL", "HTTP is allowed only for loopback buyer evaluation; use TLS and FORCE_SSL=true otherwise")
      elsif env("FORCE_SSL") == "false" && env("APP_PROTOCOL") != "http"
        fail("APP_PROTOCOL", "set APP_PROTOCOL=http for loopback evaluation HTTP")
      elsif env("FORCE_SSL") != "false" && !env("APP_PROTOCOL").empty? && env("APP_PROTOCOL") != "https"
        fail("APP_PROTOCOL", "set APP_PROTOCOL=https when SSL enforcement is enabled")
      else
        pass("FORCE_SSL", env("FORCE_SSL") == "false" ? "loopback-only evaluation HTTP selected" : "HTTPS enforcement selected")
      end
    end

    def storage
      if env("STORAGE_SERVICE") == "local"
        evaluation? ? pass("storage", "persistent local evaluation storage selected") :
          fail("storage", "local production storage requires INSTALLATION_PROFILE=buyer_evaluation")
      else
        missing = %w[STORAGE_ACCESS_KEY_ID STORAGE_SECRET_ACCESS_KEY STORAGE_REGION STORAGE_BUCKET].select { |name| env(name).empty? }
        missing.empty? ? pass("storage", "S3-compatible private storage variables are present") : fail("storage", "set: #{missing.join(', ')}")
      end
    end

    def mail
      if env("SMTP_AUTHENTICATION") == "none"
        evaluation? ? pass("mail", "unauthenticated evaluation SMTP selected") : fail("mail", "SMTP_AUTHENTICATION=none is restricted to buyer evaluation")
      else
        missing = %w[SMTP_USERNAME SMTP_PASSWORD].select { |name| env(name).empty? }
        missing.empty? ? pass("mail", "authenticated SMTP variables are present") : fail("mail", "set: #{missing.join(', ')}")
      end
    end

    def scanner
      if env("MALWARE_SCANNER_ADAPTER") == "clamav" && !env("CLAMAV_HOST").empty?
        pass("scanner", "ClamAV adapter and host are configured")
      else
        fail("scanner", "set MALWARE_SCANNER_ADAPTER=clamav and CLAMAV_HOST; prescription uploads fail closed without it")
      end
    end
  end
end
