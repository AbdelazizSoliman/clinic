module Pos
  Result = Data.define(:success?, :record, :errors)

  module Support
    private

    def success(record) = Result.new(success?: true, record:, errors: [])
    def failure(record, message) = Result.new(success?: false, record:, errors: Array(message))

    def audit(actor, subject, action, metadata = {})
      AdminAuditEvent.create!(actor:, auditable: subject, action:, metadata:)
    end
  end
end
