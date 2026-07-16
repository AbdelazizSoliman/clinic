class Fulfilment < ApplicationRecord
  belongs_to :order
  belongs_to :delivery_zone, optional: true
  belongs_to :delivery_slot, optional: true
  belongs_to :assigned_to, class_name: "User", optional: true
  belongs_to :assigned_by, class_name: "User", optional: true
  enum :status, { unassigned: 0, assigned: 1, picking: 2, packed: 3, dispatched: 4, delivered: 5 }, default: :unassigned, validate: true
  validates :order_id, uniqueness: true
  validate { errors.add(:assigned_to, "يجب أن يكون مدير طلبات أو مدير نظام") if assigned_to && !assigned_to.can_manage_delivery? }
end
