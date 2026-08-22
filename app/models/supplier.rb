class Supplier < ApplicationRecord
  has_many :purchase_orders, dependent: :restrict_with_error

  normalizes :code, with: ->(value) { value.to_s.strip.upcase }
  normalizes :email, with: ->(value) { value.to_s.strip.downcase.presence }
  normalizes :phone, with: ->(value) { value.to_s.gsub(/[^+0-9]/, "").presence }

  validates :name, :code, presence: true
  validates :name, :legal_name, :contact_person, length: { maximum: 160 }, allow_blank: true
  validates :code, length: { maximum: 40 }, format: { with: /\A[A-Z0-9][A-Z0-9_-]*\z/ },
    uniqueness: { case_sensitive: false, scope: :organization_id }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :phone, format: { with: /\A\+?[0-9]{8,15}\z/ }, allow_blank: true
  validates :lead_time_days, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :active, inclusion: { in: [ true, false ] }

  scope :active, -> { where(active: true) }

  def destroyable? = purchase_orders.none?
end
