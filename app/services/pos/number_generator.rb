module Pos
  class NumberGenerator
    def self.sale
      "POS-#{Time.current.in_time_zone('Africa/Cairo').strftime('%Y%m%d')}-#{SecureRandom.hex(4).upcase}"
    end

    def self.session
      "SHIFT-#{Time.current.in_time_zone('Africa/Cairo').strftime('%Y%m%d')}-#{SecureRandom.hex(4).upcase}"
    end
  end
end
