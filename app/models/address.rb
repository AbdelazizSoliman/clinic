class Address < ApplicationRecord
  NORMALIZED_FIELDS = %i[label recipient_name mobile_number governorate city district street building_number floor apartment landmark delivery_notes postal_code].freeze

  belongs_to :user

  validates :label, :recipient_name, :mobile_number, :governorate, :city, :street, :building_number, presence: true
  validates :label, length: { maximum: 50 }
  validates :recipient_name, length: { maximum: 120 }
  validates :mobile_number, format: { with: /\A[+0-9][0-9 ]{7,14}\z/ }
  validates :latitude, numericality: { in: -90..90 }, allow_nil: true
  validates :longitude, numericality: { in: -180..180 }, allow_nil: true
  validates :default, :active, inclusion: { in: [ true, false ] }
  validate :single_active_default

  before_validation :normalize_fields

  def summary
    [ building_number, street, district, city, governorate ].compact_blank.join("، ")
  end

  private

  def normalize_fields
    NORMALIZED_FIELDS.each do |field|
      value = public_send(field)
      public_send("#{field}=", value.to_s.squish.presence) unless value.nil?
    end
  end

  def single_active_default
    return unless active? && default? && user
    return unless user.addresses.where(active: true, default: true).where.not(id:).exists?

    errors.add(:default, "يوجد عنوان افتراضي آخر")
  end
end
