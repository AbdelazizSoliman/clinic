module Notifications
  class Create
    def self.call(user:, notifiable:, kind:, title:, body:, actor: nil, key: nil, metadata: {})
      notification = Notification.create_or_find_by!(deduplication_key: key) do |record|
        record.assign_attributes(user:, actor:, notifiable:, kind:, title:, body:, metadata: metadata.slice(:order_number, :follow_up_id))
      end
      if notification.previously_new_record? && NotificationMailer::EMAILABLE.include?(kind)
        ActiveRecord.after_all_transactions_commit do
          EmailDeliveries::Enqueue.call(user:, notification:, mailer: "NotificationMailer", action: "customer_update",
            deduplication_key: "notification:#{notification.id}:customer_update")
        end
      end
      notification
    end
  end
end
