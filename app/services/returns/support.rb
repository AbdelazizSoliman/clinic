module Returns
  Result = Data.define(:success?, :record, :errors)

  module Support
    private

    def success(record) = Result.new(success?: true, record:, errors: [])
    def failure(record, errors) = Result.new(success?: false, record:, errors: Array(errors))
    def audit(actor, record, action, metadata = {})
      AdminAuditEvent.find_or_create_by!(actor:, auditable: record, action:, metadata:)
    end
  end
end
