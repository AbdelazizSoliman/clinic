namespace :users do
  desc "Create the first admin from ADMIN_EMAIL, ADMIN_PASSWORD, ADMIN_FIRST_NAME, ADMIN_LAST_NAME and ADMIN_MOBILE"
  task create_admin: :environment do
    required = %w[ADMIN_EMAIL ADMIN_PASSWORD ADMIN_FIRST_NAME ADMIN_LAST_NAME ADMIN_MOBILE]
    missing = required.select { |key| ENV[key].blank? }
    abort "Missing: #{missing.join(', ')}" if missing.any?
    abort "ADMIN_PASSWORD must be at least 12 characters" if ENV.fetch("ADMIN_PASSWORD").length < 12
    abort "A user with this email already exists" if User.exists?(email: ENV.fetch("ADMIN_EMAIL").downcase.strip)

    user = User.create!(email: ENV.fetch("ADMIN_EMAIL"), password: ENV.fetch("ADMIN_PASSWORD"),
      first_name: ENV.fetch("ADMIN_FIRST_NAME"), last_name: ENV.fetch("ADMIN_LAST_NAME"),
      mobile_number: ENV.fetch("ADMIN_MOBILE"), role: :admin, active: true)
    UserAuditEvent.create!(user:, action: "bootstrap_admin", reason: "Bootstrap task")
    SecurityEvent.record("bootstrap_admin_created", user:, metadata: { role: user.role, action: "bootstrap" })
    puts "Bootstrap administrator created; immediate 2FA enrollment is required."
  end
end
