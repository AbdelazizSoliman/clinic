module Delivery
  class Normalizer
    DIACRITICS = /[\u064B-\u065F\u0670]/
    def self.call(value)
      value.to_s.unicode_normalize(:nfkc).delete("ـ").gsub(DIACRITICS, "").squish.downcase
    end
  end
end
