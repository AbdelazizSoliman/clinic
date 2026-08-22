class Branch < ApplicationRecord
  belongs_to :organization
  has_many :memberships, class_name: "BranchMembership", dependent: :restrict_with_error
  has_many :users, through: :memberships
  has_many :inventory_batches, dependent: :restrict_with_error
  has_many :orders, dependent: :restrict_with_error
  has_many :pos_sales, dependent: :restrict_with_error
  has_many :cashier_sessions, dependent: :restrict_with_error
  has_many :purchase_orders, dependent: :restrict_with_error

  normalizes :code, with: ->(value) { value.to_s.strip.upcase }
  validates :code, :name, :timezone, presence: true
  validates :code, uniqueness: { scope: :organization_id }, format: { with: /\A[A-Z0-9_-]+\z/ }
  validates :active, :default, :fulfilment_enabled, :pos_enabled, :purchasing_enabled, inclusion: { in: [ true, false ] }
  validate :only_one_default

  scope :active, -> { where(active: true) }
  scope :fulfilment_enabled, -> { active.where(fulfilment_enabled: true) }

  def self.default_branch = find_by(default: true) || order(:id).first
  def display_name = arabic_name.presence || name

  private

  def only_one_default
    errors.add(:default, "يوجد فرع افتراضي آخر") if default? && Branch.where(organization_id:).where.not(id:).exists?(default: true)
  end
end
