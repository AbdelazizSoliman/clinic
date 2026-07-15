class ProductsQuery
  SORTS = %w[recommended price_asc price_desc discount_desc name newest].freeze
  BOOLEAN_FILTERS = %w[discounted available prescription featured].freeze

  attr_reader :params

  def initialize(relation = Product.all, params = {})
    @relation = relation
    @params = params.to_h.stringify_keys.slice(
      "q", "category", "brand", "min_price", "max_price",
      *BOOLEAN_FILTERS, "sort"
    )
  end

  def call
    relation = @relation
    relation = search(relation)
    relation = filter_by_slug(relation, :category, params["category"])
    relation = filter_by_slug(relation, :brand, params["brand"])
    relation = filter_by_prices(relation)
    relation = relation.where("products.compare_at_price > products.price") if truthy?("discounted")
    relation = relation.where("products.stock_quantity > 0") if truthy?("available")
    relation = relation.where(requires_prescription: true) if truthy?("prescription")
    relation = relation.where(featured: true) if truthy?("featured")
    sort(relation)
  end

  def invalid_price_range?
    minimum_price && maximum_price && minimum_price > maximum_price
  end

  def sort_key
    SORTS.include?(params["sort"]) ? params["sort"] : "recommended"
  end

  private

  def search(relation)
    return relation if params["q"].blank?

    query = "%#{ActiveRecord::Base.sanitize_sql_like(params["q"].strip)}%"
    relation.left_joins(:brand, :category).where(
      "products.name ILIKE :query OR products.short_description ILIKE :query OR brands.name ILIKE :query OR categories.name ILIKE :query",
      query: query
    ).distinct
  end

  def filter_by_slug(relation, association, slug)
    return relation if slug.blank?

    relation.joins(association).where(association.to_s.pluralize => { slug: slug })
  end

  def filter_by_prices(relation)
    return relation.none if invalid_price_range?

    relation = relation.where("products.price >= ?", minimum_price) if minimum_price
    relation = relation.where("products.price <= ?", maximum_price) if maximum_price
    relation
  end

  def minimum_price = decimal(params["min_price"])
  def maximum_price = decimal(params["max_price"])

  def decimal(value)
    return if value.blank?

    number = BigDecimal(value.to_s)
    number if number >= 0
  rescue ArgumentError
    nil
  end

  def truthy?(key) = params[key] == "true"

  def sort(relation)
    case sort_key
    when "price_asc" then relation.order(price: :asc, id: :desc)
    when "price_desc" then relation.order(price: :desc, id: :desc)
    when "discount_desc"
      relation.order(Arel.sql("((products.compare_at_price - products.price) / NULLIF(products.compare_at_price, 0)) DESC NULLS LAST"), id: :desc)
    when "name" then relation.order(name: :asc, id: :desc)
    when "newest" then relation.order(created_at: :desc, id: :desc)
    else relation.order(featured: :desc, stock_quantity: :desc, id: :desc)
    end
  end
end
