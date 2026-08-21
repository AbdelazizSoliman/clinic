module Loyalty
  Result = Data.define(:success?, :record, :points, :value_cents, :errors)
  module Support
    private
    def success(record, points: 0, value_cents: 0) = Result.new(success?: true, record:, points:, value_cents:, errors: [])
    def failure(record, errors) = Result.new(success?: false, record:, points: 0, value_cents: 0, errors: Array(errors))
    def audit(actor, subject, action, metadata = {})
      AdminAuditEvent.create!(actor:, auditable: subject, action:, metadata:) if actor
    end
  end
end
