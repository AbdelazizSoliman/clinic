class StructuredLogFormatter < Logger::Formatter
  def call(severity, timestamp, _progname, message)
    payload = message.is_a?(Hash) ? message : { message: message.to_s }
    payload.slice!(:request_id, :controller, :action, :status, :duration, :user_role,
      :public_order_number, :job_class, :event_type, :error_class, :message,
      :processed, :failed)
    payload.merge(timestamp: timestamp.utc.iso8601(6), severity:).to_json << "\n"
  end
end
