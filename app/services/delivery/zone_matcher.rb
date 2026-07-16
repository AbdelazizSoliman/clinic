module Delivery
  class ZoneMatcher
    Result = Data.define(:matched?, :zone, :error)
    def self.call(address)
      return Result.new(matched?: false, zone: nil, error: "العنوان غير مكتمل") unless address
      governorate = Normalizer.call(address.governorate)
      city = Normalizer.call(address.city)
      district = Normalizer.call(address.district)
      candidates = DeliveryZone.active.includes(:districts).select do |zone|
        Normalizer.call(zone.governorate) == governorate && Normalizer.call(zone.city) == city &&
          (zone.districts.active.empty? || zone.districts.active.any? { |entry| entry.normalized_name == district })
      end
      return Result.new(matched?: true, zone: candidates.first, error: nil) if candidates.one?
      Result.new(matched?: false, zone: nil, error: candidates.many? ? "العنوان يطابق أكثر من منطقة توصيل" : "العنوان خارج نطاق التوصيل التجريبي؛ لا توجد منطقة توصيل نشطة مطابقة")
    end
  end
end
