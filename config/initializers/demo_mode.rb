module DemoMode
  TRUE_VALUES = %w[1 true t yes y on].freeze

  def self.parse(value)
    TRUE_VALUES.include?(value.to_s.strip.downcase)
  end

  def self.enabled?
    Rails.application.config.x.demo_mode == true
  end
end

Rails.application.config.x.demo_mode = DemoMode.parse(ENV.fetch("DEMO_MODE", nil))
Rails.application.config.x.demo_protected_actions = []
