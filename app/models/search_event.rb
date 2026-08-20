# Privacy-conscious, aggregate-oriented record of one executed search.
#
# No user, session, IP or prescription content is stored. The `substitution` context
# additionally stores no query text at all: those queries are typed while a specific
# patient's prescription is on screen, so only the irreversible fingerprint is kept.
class SearchEvent < ApplicationRecord
  CONTEXTS = %w[storefront pos substitution staff suggestion].freeze
  TEXTLESS_CONTEXTS = %w[substitution].freeze

  belongs_to :selected_product, class_name: "Product", optional: true

  scope :zero_result, -> { where(zero_result: true) }
  scope :with_text, -> { where.not(normalized_query: nil) }

  validates :context, inclusion: { in: CONTEXTS }
  validates :query_fingerprint, presence: true, length: { maximum: 40 }
  validates :normalized_query, length: { maximum: 120 }, allow_nil: true
  validates :result_count, :token_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate { errors.add(:zero_result, "لا يطابق عدد النتائج") unless zero_result? == result_count.zero? }
  validate :textless_context_stores_no_query
  before_update { throw :abort }

  def self.records_query_text?(context) = !TEXTLESS_CONTEXTS.include?(context.to_s)

  private

  def textless_context_stores_no_query
    return if self.class.records_query_text?(context) || normalized_query.blank?

    errors.add(:normalized_query, "لا يُخزَّن نص البحث في هذا السياق")
  end
end
