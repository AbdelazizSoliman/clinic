module Orders
  class NumberGenerator
    def self.call
      loop do
        number = "PH-#{Date.current.strftime('%Y%m%d')}-#{SecureRandom.alphanumeric(6).upcase}"
        return number unless Order.exists?(number:)
      end
    end
  end
end
