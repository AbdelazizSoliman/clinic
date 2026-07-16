class Rack::Attack
  Rack::Attack.cache.store = Rails.cache

  safelist("health checks") { |request| request.path == "/up" || request.path == "/health/ready" }
  safelist("assets") { |request| request.path.start_with?("/assets/") }

  throttle("authentication/ip", limit: 10, period: 5.minutes) do |request|
    request.ip if request.post? && request.path.in?([ "/users/sign_in", "/users/password", "/two_factor_challenge" ])
  end
  throttle("authentication/account", limit: 6, period: 15.minutes) do |request|
    request.params.dig("user", "email").to_s.strip.downcase.presence if request.post? && request.path.start_with?("/users/")
  end
  throttle("coupon/ip", limit: 20, period: 10.minutes) do |request|
    request.ip if request.post? && request.path == "/coupon_application"
  end
  throttle("exports/ip", limit: 10, period: 1.hour) do |request|
    request.ip if request.post? && request.path == "/report_exports"
  end
  throttle("sensitive-admin/ip", limit: 20, period: 1.hour) do |request|
    request.ip if request.patch? && request.path.match?(%r{\A/admin/(users/\d+/revoke_sessions|email_deliveries/\d+/retry)\z})
  end

  self.throttled_responder = lambda do |request|
    retry_after = request.env["rack.attack.match_data"][:period].to_i
    body = Rails.public_path.join("429.html").read
    [ 429, { "Content-Type" => "text/html; charset=utf-8", "Retry-After" => retry_after.to_s }, [ body ] ]
  end
end
