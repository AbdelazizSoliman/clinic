module EmailDeliveries
  class Enqueue
    def self.call(user:, mailer:, action:, deduplication_key:, notification: nil)
      delivery = TransactionalEmailDelivery.find_or_create_by!(deduplication_key:) do |record|
        record.assign_attributes(user:, notification:, mailer:, action:, status: :queued, queued_at: Time.current)
      end
      TransactionalEmailDeliveryJob.perform_later(delivery.id) if delivery.previously_new_record?
      delivery
    rescue ActiveRecord::RecordNotUnique
      retry
    end
  end
end
