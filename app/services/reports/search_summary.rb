module Reports
  # Aggregate search-behaviour metrics. These describe what was typed into the search
  # box and how many records matched — nothing about who typed it, and nothing clinical.
  class SearchSummary
    Result = Data.define(:cards, :context_counts, :top_queries, :zero_result_queries,
      :selected_products, :selection_ratio)

    def initialize(range) = @range = range

    def call
      events = SearchEvent.where(created_at: @range.range)
      searches = events.count
      selections = events.where.not(selected_product_id: nil).count
      Result.new(
        cards: { searches:, zero_results: events.zero_result.count, selections:,
                 distinct_queries: events.distinct.count(:query_fingerprint) },
        context_counts: events.group(:context).count,
        top_queries: grouped_queries(events.with_text),
        zero_result_queries: grouped_queries(events.with_text.zero_result),
        selected_products: selected_products(events),
        selection_ratio: searches.zero? ? nil : (selections * 100.0 / searches).round(1)
      )
    end

    private

    def grouped_queries(scope)
      scope.group(:normalized_query).order(Arel.sql("COUNT(*) DESC"), Arel.sql("normalized_query ASC"))
        .limit(15).count.map { |query, count| { query:, count: } }
    end

    def selected_products(events)
      counts = events.where.not(selected_product_id: nil).group(:selected_product_id)
        .order(Arel.sql("COUNT(*) DESC")).limit(10).count
      names = Product.where(id: counts.keys).pluck(:id, :name).to_h
      counts.map { |id, count| { name: names[id] || "—", count: } }
    end
  end
end
