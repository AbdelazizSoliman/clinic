module Wallet
  Result = Data.define(:success?, :record, :errors)
  module Support
    private
    def success(record) = Result.new(success?: true, record:, errors: [])
    def failure(record, errors) = Result.new(success?: false, record:, errors: Array(errors))
    def audit(actor, subject, action, metadata = {})
      AdminAuditEvent.create!(actor:, auditable: subject, action:, metadata:) if actor
    end
  end
end
