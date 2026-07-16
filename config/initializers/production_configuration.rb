if Rails.env.production? && !ENV["SECRET_KEY_BASE_DUMMY"]
  required = %w[DATABASE_URL APP_HOST ALLOWED_HOSTS SMTP_ADDRESS SMTP_USERNAME SMTP_PASSWORD MAIL_FROM_EMAIL MAIL_FROM_NAME
    STORAGE_ACCESS_KEY_ID STORAGE_SECRET_ACCESS_KEY STORAGE_REGION STORAGE_BUCKET
    ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY
    ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT SECURITY_EVENT_DIGEST_KEY]
  missing = required.select { |name| ENV[name].blank? }
  missing << "RAILS_MASTER_KEY or SECRET_KEY_BASE" if ENV["RAILS_MASTER_KEY"].blank? && ENV["SECRET_KEY_BASE"].blank?
  raise "Production configuration missing required variables: #{missing.join(', ')}" if missing.any?
  if ENV["MALWARE_SCANNER_ADAPTER"] == "clamav" && ENV["CLAMAV_HOST"].blank?
    raise "Production ClamAV configuration missing CLAMAV_HOST"
  end

  unless ActiveRecord::Encryption.config.primary_key.present? &&
      ActiveRecord::Encryption.config.deterministic_key.present? &&
      ActiveRecord::Encryption.config.key_derivation_salt.present?
    raise "Production configuration missing Active Record encryption keys"
  end
end
