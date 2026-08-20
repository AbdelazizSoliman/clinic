# Keeps the normalized `search_*` projections in sync with the record's own columns.
#
# Only columns owned by the record itself are projected, so a plain `before_save`
# is always sufficient: renaming a brand can never leave a product's projection
# stale, because a product never stores its brand's text.
module Searchable
  extend ActiveSupport::Concern

  class_methods do
    # `name_source` feeds `search_name` (exact/prefix matching and fuzzy similarity).
    # `term_sources` additionally feed `search_terms` (token matching).
    def searchable_by(name_source, term_sources: [])
      class_attribute :search_name_source, default: name_source
      class_attribute :search_term_sources, default: Array(term_sources)
      before_save :refresh_search_projections
    end
  end

  def refresh_search_projections
    self.search_name = Search::ArabicNormalizer.normalize(public_send(self.class.search_name_source))
    return unless has_attribute?(:search_terms)

    sources = [ self.class.search_name_source, *self.class.search_term_sources ]
    self.search_terms = Search::ArabicNormalizer.normalize(sources.filter_map { |field| public_send(field) }.join(" "))
  end
end
