# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src :self, :data
    policy.img_src :self, :data, :blob
    policy.connect_src :self
    policy.frame_src :none
    policy.object_src :none
    policy.script_src :self
    policy.style_src :self, :unsafe_inline
    policy.base_uri :self
    policy.form_action :self
    policy.frame_ancestors :none
    # Specify a protected report URI only after an ingestion service is selected.
    # policy.report_uri "/csp-violation-report-endpoint"
  end
  # Generate per-response script nonces. Tailwind currently requires inline styles;
  # removing style-src unsafe-inline is tracked as a launch hardening follow-up.
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
  # A protected provider endpoint may be configured for violation reports in Phase 15.
end
