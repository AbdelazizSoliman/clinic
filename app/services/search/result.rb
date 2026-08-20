module Search
  # A bounded, already-ordered set of product matches plus the metadata the UI and the
  # analytics recorder need. Loading is lazy and happens exactly once.
  class Result
    attr_reader :query, :context, :limit

    def self.empty(query:, context:) = new(query:, context:, records: Product.none, limit: 0)

    def initialize(query:, context:, records:, limit:)
      @query = query
      @context = context
      @records = records
      @limit = limit
    end

    def records = @loaded ||= @records.to_a
    def count = records.size
    def any? = records.any?
    def empty? = records.empty?
    def truncated? = limit.positive? && count >= limit

    # The record an operational identifier resolved to, if the top hit was an exact
    # barcode or SKU match. POS uses this to keep scanning unambiguous.
    def exact_identifier_match
      return nil unless query.identifier_candidate?

      records.first if records.first && identifier_match?(records.first)
    end

    private

    def identifier_match?(product)
      product.barcode == query.identifier || product.sku.to_s.upcase == query.sku_candidate
    end
  end
end
