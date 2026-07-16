module Errors
  class Reporter
    SAFE_KEYS = %i[environment release request_id job_class actor_role public_order_number].freeze

    def self.capture(error, context: {})
      adapter.capture(error.class.name, safe_context(context))
    rescue => reporter_error
      Rails.logger.warn("error_reporter_failure=#{reporter_error.class.name}")
      nil
    end

    def self.adapter
      case ENV.fetch("ERROR_REPORTER_ADAPTER", "logging")
      when "logging" then LoggingAdapter.new
      when "external" then ExternalAdapter.new
      else LoggingAdapter.new
      end
    end

    def self.safe_context(context)
      context.to_h.symbolize_keys.slice(*SAFE_KEYS).merge(
        environment: Rails.env,
        release: ENV.fetch("RELEASE_SHA", "unknown")
      ).compact
    end

    class LoggingAdapter
      def capture(error_class, context)
        Rails.logger.error({ event_type: "reported_error", error_class:, **context }.to_json)
      end
    end

    class ExternalAdapter
      def capture(_error_class, _context)
        raise NotImplementedError, "Configure a reviewed external error-reporting adapter"
      end
    end
  end
end
