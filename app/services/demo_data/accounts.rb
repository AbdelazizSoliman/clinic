module DemoData
  module Accounts
    DOMAIN = "example.test"
    DEFINITIONS = {
      admin: { email: "admin@#{DOMAIN}", role: :admin, first_name: "مدير", last_name: "العرض", mobile: "01000000001" },
      pharmacist: { email: "pharmacist@#{DOMAIN}", role: :pharmacist, first_name: "سلمى", last_name: "الصيدلانية", mobile: "01000000002" },
      order_manager: { email: "staff@#{DOMAIN}", role: :order_manager, first_name: "عمر", last_name: "العمليات", mobile: "01000000003" },
      inventory_manager: { email: "inventory@#{DOMAIN}", role: :inventory_manager, first_name: "منى", last_name: "المخزون", mobile: "01000000004" },
      customer: { email: "customer@#{DOMAIN}", role: :customer, first_name: "ليلى", last_name: "حسن", mobile: "01000000005" },
      prescription_customer: { email: "prescription.customer@#{DOMAIN}", role: :customer, first_name: "نور", last_name: "محمود", mobile: "01000000006" },
      cancelled_customer: { email: "cancelled.customer@#{DOMAIN}", role: :customer, first_name: "كريم", last_name: "سامي", mobile: "01000000007" }
    }.freeze

    def self.protected?(user)
      DemoMode.enabled? && user&.email.to_s.downcase.in?(DEFINITIONS.values.map { |definition| definition[:email] })
    end
  end
end
