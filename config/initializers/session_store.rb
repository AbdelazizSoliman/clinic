Rails.application.config.session_store :cookie_store,
  key: "_clinic_session",
  secure: Rails.env.production? && ENV.fetch("FORCE_SSL", "true") == "true",
  httponly: true,
  same_site: :lax,
  expire_after: 12.hours
