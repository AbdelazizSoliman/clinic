class DeliveryZoneDistrict < ApplicationRecord
  belongs_to :delivery_zone
  validates :name, :normalized_name, presence: true
  validates :normalized_name, uniqueness: { scope: :delivery_zone_id }
  before_validation { self.normalized_name = Delivery::Normalizer.call(name) }
  scope :active, -> { where(active: true) }
end
