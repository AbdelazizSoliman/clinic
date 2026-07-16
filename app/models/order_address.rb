class OrderAddress < ApplicationRecord
  belongs_to :order

  validates :label, :recipient_name, :mobile_number, :governorate, :city, :street, :building_number, presence: true
  validates :order_id, uniqueness: true

  def summary
    [ building_number, street, district, city, governorate ].compact_blank.join("، ")
  end
end
