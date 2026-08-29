if Rails.env.production? && !ENV["SECRET_KEY_BASE_DUMMY"]
  profile = ENV.fetch("INSTALLATION_PROFILE", "")
  unless %w[production buyer_evaluation].include?(profile) || profile.empty?
    raise "INSTALLATION_PROFILE must be production, buyer_evaluation, or empty"
  end
  evaluation = profile == "buyer_evaluation"
  raise "FORCE_SSL must be true or false" unless %w[true false].include?(ENV.fetch("FORCE_SSL", "true"))
  raise "STORAGE_SERVICE must be production or local" unless %w[production local].include?(ENV.fetch("STORAGE_SERVICE", "production"))
  unless %w[plain login cram_md5 none].include?(ENV.fetch("SMTP_AUTHENTICATION", "plain"))
    raise "SMTP_AUTHENTICATION must be plain, login, cram_md5, or none"
  end
  required = %w[DATABASE_URL APP_HOST ALLOWED_HOSTS SMTP_ADDRESS MAIL_FROM_EMAIL MAIL_FROM_NAME
    ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY
    ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT SECURITY_EVENT_DIGEST_KEY]
  required.concat(%w[SMTP_USERNAME SMTP_PASSWORD]) unless ENV["SMTP_AUTHENTICATION"] == "none"
  required.concat(%w[STORAGE_ACCESS_KEY_ID STORAGE_SECRET_ACCESS_KEY STORAGE_REGION STORAGE_BUCKET]) unless ENV["STORAGE_SERVICE"] == "local"
  missing = required.select { |name| ENV[name].blank? }
  missing << "RAILS_MASTER_KEY or SECRET_KEY_BASE" if ENV["RAILS_MASTER_KEY"].blank? && ENV["SECRET_KEY_BASE"].blank?
  raise "Production configuration missing required variables: #{missing.join(', ')}" if missing.any?
  if ENV["MALWARE_SCANNER_ADAPTER"] == "clamav" && ENV["CLAMAV_HOST"].blank?
    raise "Production ClamAV configuration missing CLAMAV_HOST"
  end
  if ENV["STORAGE_SERVICE"] == "local" && !evaluation
    raise "Production local storage is restricted to INSTALLATION_PROFILE=buyer_evaluation"
  end
  if ENV["SMTP_AUTHENTICATION"] == "none" && !evaluation
    raise "Unauthenticated production SMTP is restricted to INSTALLATION_PROFILE=buyer_evaluation"
  end
  if ENV["FORCE_SSL"] == "false" && !evaluation
    raise "Disabling production SSL is restricted to INSTALLATION_PROFILE=buyer_evaluation"
  end
  if evaluation && !%w[localhost 127.0.0.1].include?(ENV["APP_HOST"])
    raise "Buyer evaluation is restricted to a loopback APP_HOST"
  end
  if evaluation && !%w[127.0.0.1 localhost].include?(ENV["WEB_BIND_ADDRESS"])
    raise "Buyer evaluation is restricted to a loopback WEB_BIND_ADDRESS"
  end

  unless ActiveRecord::Encryption.config.primary_key.present? &&
      ActiveRecord::Encryption.config.deterministic_key.present? &&
      ActiveRecord::Encryption.config.key_derivation_salt.present?
    raise "Production configuration missing Active Record encryption keys"
  end
end
