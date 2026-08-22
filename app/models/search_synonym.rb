# Deterministic, data-driven query expansion. A synonym only widens which records a
# query can *find*; it never asserts that two products are interchangeable, and it is
# deliberately unavailable to the clinical rule engine.
class SearchSynonym < ApplicationRecord
  MAX_EXPANSIONS = 4

  scope :active, -> { where(active: true) }

  before_validation :normalize

  validates :term, :expansion, presence: true, length: { maximum: 60 }
  validates :normalized_term, :normalized_expansion, presence: true, length: { minimum: 2, maximum: 60 }
  validates :normalized_expansion, uniqueness: { scope: %i[organization_id normalized_term] }
  validates :notes, length: { maximum: 500 }, allow_blank: true
  validates :active, inclusion: { in: [ true, false ] }
  validate :pair_differs

  # Expansion is one hop only: a synonym of a synonym is never followed, so the
  # expanded token set stays small, predictable and bounded.
  def self.expansions_for(tokens)
    terms = Array(tokens).map { |token| Search::ArabicNormalizer.normalize(token) }.reject(&:blank?)
    return [] if terms.empty?

    active.where(normalized_term: terms).order(:normalized_expansion)
      .limit(MAX_EXPANSIONS).pluck(:normalized_expansion)
  end

  private

  def normalize
    self.term = term.to_s.squish
    self.expansion = expansion.to_s.squish
    self.normalized_term = Search::ArabicNormalizer.normalize(term)
    self.normalized_expansion = Search::ArabicNormalizer.normalize(expansion)
  end

  def pair_differs
    return if normalized_term.blank? || normalized_term != normalized_expansion

    errors.add(:expansion, "يجب أن يختلف عن المصطلح الأصلي بعد التوحيد")
  end
end
