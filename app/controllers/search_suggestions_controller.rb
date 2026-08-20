# Public, storefront-scoped autocomplete. Only publicly available products and active
# lookups are ever exposed, and every payload is bounded.
class SearchSuggestionsController < ApplicationController
  PRODUCT_LIMIT = 6
  LOOKUP_LIMIT = 3

  def index
    @query = Search::Query.parse(params[:q])
    if @query.blank? || @query.normalized.length < 2
      return render partial: "search_suggestions/suggestions",
        locals: { query: @query, products: [], lookups: [] }
    end

    result = Search::Products.call(query: @query, context: :suggestion, limit: PRODUCT_LIMIT)
    Search::RecordEvent.call(result:)
    render partial: "search_suggestions/suggestions",
      locals: { query: @query, products: result.records, lookups: Search::Lookups.call(@query, limit: LOOKUP_LIMIT) }
  end
end
