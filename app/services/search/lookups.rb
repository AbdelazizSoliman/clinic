module Search
  # Brand / category / active-ingredient suggestions. These are navigational aids only:
  # an ingredient suggestion links to the products that carry that structured identity
  # and makes no therapeutic claim about them.
  class Lookups
    Suggestion = Data.define(:kind, :label, :value)
    MAX_LIMIT = 5

    def self.call(query, limit: 3) = new(query, limit:).call

    def initialize(query, limit:)
      @query = query.is_a?(Query) ? query : Query.parse(query)
      @limit = limit.to_i.clamp(1, MAX_LIMIT)
    end

    def call
      return [] if @query.blank? || @query.normalized.length < 2

      brands + categories + ingredients
    end

    private

    def brands
      Brand.active.where(match, pattern).order(:search_name).limit(@limit)
        .map { |brand| Suggestion.new(kind: :brand, label: brand.name, value: brand.slug) }
    end

    def categories
      Category.active.where(match, pattern).order(:search_name).limit(@limit)
        .map { |category| Suggestion.new(kind: :category, label: category.name, value: category.slug) }
    end

    def ingredients
      ActiveIngredient.active.where(match, pattern).order(:search_name).limit(@limit)
        .map { |ingredient| Suggestion.new(kind: :ingredient, label: ingredient.name, value: ingredient.name) }
    end

    def match = "search_name LIKE ?"
    def pattern = "%#{ActiveRecord::Base.sanitize_sql_like(@query.normalized)}%"
  end
end
