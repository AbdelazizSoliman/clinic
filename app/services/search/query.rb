module Search
  # A parsed, bounded search query. Immutable and safe to reuse across contexts.
  class Query
    MAX_RAW_LENGTH = 120
    MAX_TOKENS = 8
    MIN_FUZZY_LENGTH = 4

    attr_reader :raw, :normalized, :identifier, :tokens

    def self.parse(raw, expand_synonyms: true) = new(raw, expand_synonyms:)

    def initialize(raw, expand_synonyms: true)
      @raw = raw.to_s.slice(0, MAX_RAW_LENGTH).to_s
      @normalized = ArabicNormalizer.normalize(@raw)
      @identifier = ArabicNormalizer.normalize_identifier(@raw)
      @tokens = build_tokens(expand_synonyms)
    end

    def blank? = normalized.blank?
    def present? = !blank?
    def length = normalized.length

    # Trigram similarity on very short strings is noise, so fuzzy matching is only
    # offered once the query is long enough for trigrams to mean something.
    def fuzzy_eligible? = normalized.length >= MIN_FUZZY_LENGTH
    def identifier_candidate? = identifier.present? && identifier.length >= 3
    def sku_candidate = identifier.upcase
    def fingerprint = Digest::SHA256.hexdigest(normalized)[0, 40]

    private

    def build_tokens(expand_synonyms)
      base = ArabicNormalizer.tokenize(@raw).first(MAX_TOKENS)
      return base unless expand_synonyms && base.any?

      (base + SearchSynonym.expansions_for(base)).uniq.first(MAX_TOKENS)
    end
  end
end
