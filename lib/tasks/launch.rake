namespace :launch do
  desc "Safe production launch smoke checks; creates only temporary storage/cache data"
  task smoke: :environment do
    results = {}
    temporary_blob = nil
    cache_key = "launch-smoke:#{SecureRandom.hex(8)}"

    begin
      ActiveRecord::Base.connection.select_value("SELECT 1")
      ActiveRecord::Migration.check_all_pending!
      results[:database_and_schema] = :ok

      setting = PharmacySetting.first
      raise "PharmacySetting is missing" unless setting
      results[:settings] = :ok

      admins = User.admin.where(active: true)
      raise "No active administrator exists" unless admins.exists?
      raise "An active administrator has not completed 2FA" if admins.where(otp_enabled_at: nil).exists?
      results[:administrator_and_2fa] = :ok

      Rails.cache.write(cache_key, "ok", expires_in: 1.minute)
      raise "Shared cache read/write failed" unless Rails.cache.read(cache_key) == "ok"
      results[:cache] = :ok

      temporary_blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new("Phase 15 non-medical launch smoke file\n"),
        filename: "launch-smoke.txt", content_type: "text/plain"
      )
      raise "Private storage read failed" unless temporary_blob.download.include?("non-medical")
      results[:storage] = :ok

      raise "SMTP delivery method is not configured" unless ActionMailer::Base.delivery_method == :smtp || !Rails.env.production?
      results[:mail_configuration] = :ok

      job = LaunchSmokeJob.perform_later
      raise "Job enqueue did not return an identifier" if job.job_id.blank?
      results[:job_enqueue] = :ok

      Rails.application.routes.url_helpers.rails_health_check_path
      Rails.application.routes.url_helpers.readiness_check_path
      Rails.application.routes.url_helpers.new_user_session_path
      Rails.application.routes.url_helpers.admin_security_path
      results[:critical_routes] = :ok

      if ENV["MALWARE_SCANNER_ADAPTER"] == "clamav"
        scan_blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("clean scanner health probe"),
          filename: "scanner-health.txt", content_type: "text/plain")
        begin
          raise "Scanner clean probe failed" unless Uploads::Scanner.call(scan_blob) == :clean
          results[:scanner] = :ok
        ensure
          scan_blob.purge
        end
      else
        results[:scanner] = :not_configured
      end

      results.each { |name, status| puts "#{name}=#{status}" }
      abort "Launch smoke failed: real malware scanner is not configured" if Rails.env.production? && results[:scanner] != :ok
      puts "launch_smoke=ok"
    rescue => error
      warn "launch_smoke=failed check_error=#{error.class.name}"
      raise
    ensure
      Rails.cache.delete(cache_key)
      temporary_blob&.purge
    end
  end
end
