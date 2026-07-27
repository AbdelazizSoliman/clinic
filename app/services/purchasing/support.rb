module Purchasing
  module Support
    private

    def audit(subject, action, data = {})
      AdminAuditEvent.create!(actor: @actor, auditable: subject, action:, change_data: data)
    end

    def event(order, type, from: nil, to: nil, metadata: {})
      order.events.create!(actor: @actor, event_type: type, from_status: from, to_status: to, metadata:)
    end

    def notify(users, order, kind, title, key)
      users.find_each do |user|
        Notifications::Create.call(user:, actor: @actor, notifiable: order, kind:, title:,
          body: "أمر الشراء #{order.number}", key: "#{key}:#{user.id}")
      end
    end
  end
end
