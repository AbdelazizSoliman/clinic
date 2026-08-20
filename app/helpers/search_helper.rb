module SearchHelper
  LOOKUP_LABELS = { brand: "علامة", category: "قسم", ingredient: "مادة فعالة" }.freeze

  def lookup_suggestion_label(kind) = LOOKUP_LABELS.fetch(kind.to_sym, kind.to_s)

  # Ingredient suggestions search the catalogue by that ingredient's name; they never
  # assert that the resulting products are clinically interchangeable.
  def lookup_suggestion_path(suggestion)
    case suggestion.kind
    when :brand then products_path(brand: suggestion.value)
    when :category then products_path(category: suggestion.value)
    else products_path(q: suggestion.value)
    end
  end

  # Nearby brands, categories and ingredients for a query that matched no product.
  # These are navigational alternatives, never a corrected clinical term.
  def search_fallback_suggestions(raw_query)
    return [] if raw_query.blank?

    Search::Lookups.call(raw_query, limit: 3)
  end

  def search_context_label(context)
    { "storefront" => "المتجر", "pos" => "نقطة البيع", "substitution" => "البدائل العلاجية",
      "staff" => "بحث الموظفين", "suggestion" => "اقتراحات فورية" }.fetch(context.to_s, context.to_s)
  end
end
