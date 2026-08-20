module Search
  # The single product-discovery entry point for every context in the application.
  #
  # Ranking is a deterministic integer tier plus a similarity tie-break, so identical
  # data and an identical query always produce the same ordering. Operational
  # identifiers (barcode, SKU) are pinned above every textual match by construction:
  # they occupy tiers 0 and 1 and no fuzzy score can promote a record past them.
  #
  # Every SQL fragment below is a frozen literal template; user input only ever reaches
  # the database as a bound value through `where(template, *values)` or
  # `sanitize_sql_array`. No query text is interpolated into SQL anywhere.
  class Products
    # A SQL predicate template plus its bind values. Templates are literals defined in
    # this file; values are whatever the user typed.
    Fragment = Data.define(:sql, :values) do
      def self.join(fragments, operator)
        Fragment.new(sql: "(#{fragments.map(&:sql).join(operator)})", values: fragments.flat_map(&:values))
      end

      def to_literal = ActiveRecord::Base.sanitize_sql_array([ sql, *values ])
    end

    DEFAULT_LIMIT = 30
    MAX_LIMIT = 50
    # Fuzzy matching scores the query against the best matching *word extent* of the
    # product name (`word_similarity`), not the whole string. Measured on this catalogue,
    # a correct word scores 1.0, a one-character typo ~0.57, and an unrelated name 0.0,
    # so 0.5 accepts real typos while rejecting noise. Whole-string `similarity` was
    # rejected: a correct one-word query against a long product name scores only ~0.32.
    SIMILARITY_THRESHOLD = 0.5

    CONTEXTS = {
      storefront: { relation: -> { Product.publicly_available }, min_length: 2 },
      suggestion: { relation: -> { Product.publicly_available }, min_length: 2 },
      pos: { relation: -> { Product.active }, min_length: 2 },
      substitution: { relation: -> { Product.active.where(requires_prescription: true) }, min_length: 2,
                      allocatable: true },
      staff: { relation: -> { Product.all }, min_length: 2 }
    }.freeze

    RANK_EXACT_BARCODE = 0
    RANK_EXACT_SKU = 1
    RANK_EXACT_NAME = 2
    RANK_NAME_PREFIX = 3
    RANK_TOKENS_IN_NAME = 4
    RANK_TOKENS_ANYWHERE = 5
    RANK_FUZZY = 6

    # Sellability as an EXISTS over allocatable batches: a product whose only stock sits in
    # an expired or quarantined batch can never look sellable, and no join duplicates a row.
    ALLOCATABLE_SQL = <<~SQL.squish.freeze
      EXISTS (SELECT 1 FROM inventory_batches ib
              WHERE ib.product_id = products.id
                AND ib.quarantined_at IS NULL
                AND (ib.expiry_date IS NULL OR ib.expiry_date >= CURRENT_DATE)
                AND ib.on_hand_quantity > ib.reserved_quantity)
    SQL

    # Structured Phase 20 identity only. The legacy free-text `products.active_ingredient`
    # column is display metadata and is never treated as clinical identity here.
    INGREDIENT_SQL = <<~SQL.squish.freeze
      EXISTS (SELECT 1 FROM product_active_ingredients pai
              JOIN active_ingredients ai ON ai.id = pai.active_ingredient_id
              WHERE pai.product_id = products.id AND pai.active AND ai.active AND ai.search_name LIKE ?)
    SQL

    BRAND_SQL = "EXISTS (SELECT 1 FROM brands b WHERE b.id = products.brand_id AND b.search_name LIKE ?)".freeze
    CATEGORY_SQL = "EXISTS (SELECT 1 FROM categories c WHERE c.id = products.category_id AND c.search_name LIKE ?)".freeze

    def self.call(query:, context: :storefront, relation: nil, limit: DEFAULT_LIMIT)
      new(query:, context:, relation:, limit:).call
    end

    def initialize(query:, context:, relation: nil, limit: DEFAULT_LIMIT)
      @query = query.is_a?(Query) ? query : Query.parse(query)
      @context = context.to_sym
      @settings = CONTEXTS.fetch(@context)
      @relation = relation || @settings.fetch(:relation).call
      @limit = limit.to_i.clamp(1, MAX_LIMIT)
    end

    def call
      return Result.empty(query: @query, context: @context) if too_short?

      Result.new(query: @query, context: @context, limit: @limit,
        records: relation.reorder(*rank_ordering).limit(@limit))
    end

    # Relation-only variant for callers that own their own pagination and filters
    # (the storefront browser keeps its category/brand/price/sort pipeline).
    def relation
      return @relation.none if too_short?

      condition = match_condition
      filtered_relation.where(condition.sql, *condition.values)
    end

    def rank_ordering
      [ Arel.sql("#{rank_case.to_literal} ASC"), Arel.sql("#{similarity_expression.to_literal} DESC"),
        Arel.sql("products.search_name ASC"), Arel.sql("products.id ASC") ]
    end

    def query_object = @query

    private

    def too_short? = @query.blank? || @query.normalized.length < @settings.fetch(:min_length)
    def filtered_relation = @settings[:allocatable] ? @relation.where(ALLOCATABLE_SQL) : @relation

    def match_condition
      Fragment.join([ exact_barcode, exact_sku, exact_name, prefix, tokens_anywhere, fuzzy ].compact, " OR ")
    end

    def rank_case
      tiers = [ [ exact_barcode, RANK_EXACT_BARCODE ], [ exact_sku, RANK_EXACT_SKU ],
        [ exact_name, RANK_EXACT_NAME ], [ prefix, RANK_NAME_PREFIX ],
        [ tokens_in_name, RANK_TOKENS_IN_NAME ], [ tokens_anywhere, RANK_TOKENS_ANYWHERE ] ].compact
      present = tiers.select { |fragment, _rank| fragment }
      Fragment.new(sql: "(CASE #{present.map { |fragment, rank| "WHEN #{fragment.sql} THEN #{rank}" }.join(' ')} ELSE #{RANK_FUZZY} END)",
        values: present.flat_map { |fragment, _rank| fragment.values })
    end

    def similarity_expression
      # An explicit cast: a bare integer literal in ORDER BY is read as a column position.
      return Fragment.new(sql: "CAST(0 AS real)", values: []) unless @query.fuzzy_eligible?

      Fragment.new(sql: "word_similarity(?, products.search_name)", values: [ @query.normalized ])
    end

    def exact_barcode
      return nil unless @query.identifier_candidate?

      Fragment.new(sql: "products.barcode = ?", values: [ @query.identifier ])
    end

    def exact_sku
      return nil unless @query.identifier_candidate?

      Fragment.new(sql: "upper(products.sku::text) = ?", values: [ @query.sku_candidate ])
    end

    def exact_name = Fragment.new(sql: "products.search_name = ?", values: [ @query.normalized ])

    def prefix
      Fragment.new(sql: "products.search_name LIKE ?", values: [ "#{escape_like(@query.normalized)}%" ])
    end

    def tokens_in_name
      return nil if @query.tokens.empty?

      Fragment.join(@query.tokens.map do |token|
        Fragment.new(sql: "products.search_terms LIKE ?", values: [ contains(token) ])
      end, " AND ")
    end

    # A multi-token query does not require every token to live in one field: each token may
    # be satisfied by the product's own text, its brand, its category, or a structured
    # active ingredient.
    def tokens_anywhere
      return nil if @query.tokens.empty?

      Fragment.join(@query.tokens.map { |token| token_surface(token) }, " AND ")
    end

    def token_surface(token)
      pattern = contains(token)
      Fragment.new(sql: "(products.search_terms LIKE ? OR #{BRAND_SQL} OR #{CATEGORY_SQL} OR #{INGREDIENT_SQL})",
        values: [ pattern, pattern, pattern, pattern ])
    end

    def fuzzy
      return nil unless @query.fuzzy_eligible?

      Fragment.new(sql: "word_similarity(?, products.search_name) >= ?",
        values: [ @query.normalized, SIMILARITY_THRESHOLD ])
    end

    def contains(token) = "%#{escape_like(token)}%"
    def escape_like(value) = ActiveRecord::Base.sanitize_sql_like(value)
  end
end
