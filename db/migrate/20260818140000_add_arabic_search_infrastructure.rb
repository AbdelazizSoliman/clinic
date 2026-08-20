class AddArabicSearchInfrastructure < ActiveRecord::Migration[8.1]
  NORMALIZED_LOOKUPS = { brands: :name, categories: :name, active_ingredients: :name }.freeze
  EXPORT_CONSTRAINT = "report_export_events_type_valid".freeze
  EXPORT_TYPES = %w[sales orders products inventory promotions customers prescriptions
    fulfilments purchasing batches pos drug_safety].freeze

  def up
    enable_extension "pg_trgm" unless extension_enabled?("pg_trgm")
    add_product_search_columns
    add_lookup_search_columns
    create_synonyms
    create_search_events
    backfill_products
    NORMALIZED_LOOKUPS.each_key { |table| backfill_lookup(table) }
    replace_export_types(EXPORT_TYPES + %w[search])
  end

  def down
    replace_export_types(EXPORT_TYPES)
    drop_table :search_events
    drop_table :search_synonyms
    NORMALIZED_LOOKUPS.each_key do |table|
      remove_index table, name: "index_#{table}_on_search_name_trgm"
      remove_column table, :search_name
    end
    remove_index :products, name: "index_products_on_upper_sku"
    remove_index :products, name: "index_products_on_search_terms_trgm"
    remove_index :products, name: "index_products_on_search_name_trgm"
    remove_column :products, :search_terms
    remove_column :products, :search_name
    disable_extension "pg_trgm" if extension_enabled?("pg_trgm")
  end

  private

  def add_product_search_columns
    # Normalized projections of the product's OWN columns only, so a plain model
    # callback keeps them correct without any cross-record invalidation.
    add_column :products, :search_name, :string
    add_column :products, :search_terms, :text
    # Trigram GIN indexes serve both the `LIKE '%token%'` token pass and the
    # similarity() fuzzy pass; neither can use a B-tree index.
    add_index :products, :search_name, using: :gin, opclass: :gin_trgm_ops,
      name: "index_products_on_search_name_trgm"
    add_index :products, :search_terms, using: :gin, opclass: :gin_trgm_ops,
      name: "index_products_on_search_terms_trgm"
    # Exact identifier lookups are case-insensitive; barcode already has a unique
    # B-tree index and is compared verbatim.
    add_index :products, "upper(sku::text)", name: "index_products_on_upper_sku", where: "sku IS NOT NULL"
  end

  def add_lookup_search_columns
    NORMALIZED_LOOKUPS.each_key do |table|
      add_column table, :search_name, :string
      add_index table, :search_name, using: :gin, opclass: :gin_trgm_ops,
        name: "index_#{table}_on_search_name_trgm"
    end
  end

  def create_synonyms
    create_table :search_synonyms do |t|
      t.string :term, null: false
      t.string :normalized_term, null: false
      t.string :expansion, null: false
      t.string :normalized_expansion, null: false
      t.boolean :active, null: false, default: true
      t.text :notes
      t.timestamps
      t.index %i[normalized_term normalized_expansion], unique: true, name: "index_search_synonyms_unique_pair"
      t.index %i[active normalized_term], name: "index_search_synonyms_lookup"
      t.check_constraint "normalized_term <> normalized_expansion", name: "search_synonyms_pair_differs"
      t.check_constraint "char_length(normalized_term) BETWEEN 2 AND 60", name: "search_synonyms_term_length"
      t.check_constraint "char_length(normalized_expansion) BETWEEN 2 AND 60", name: "search_synonyms_expansion_length"
    end
  end

  def create_search_events
    create_table :search_events do |t|
      t.string :context, null: false
      t.string :normalized_query
      t.string :query_fingerprint, null: false
      t.integer :token_count, null: false, default: 0
      t.integer :result_count, null: false, default: 0
      t.boolean :zero_result, null: false, default: false
      t.references :selected_product, foreign_key: { to_table: :products }
      t.datetime :created_at, null: false
      t.index %i[context created_at], name: "index_search_events_on_context_and_created_at"
      t.index %i[query_fingerprint created_at], name: "index_search_events_on_fingerprint_and_created_at"
      t.index %i[zero_result created_at], name: "index_search_events_on_zero_result_and_created_at"
      t.check_constraint "context IN ('storefront','pos','substitution','staff','suggestion')",
        name: "search_events_context_valid"
      t.check_constraint "result_count >= 0 AND token_count >= 0", name: "search_events_counts_nonnegative"
      t.check_constraint "zero_result = (result_count = 0)", name: "search_events_zero_result_consistent"
      t.check_constraint "char_length(normalized_query) <= 120", name: "search_events_query_bounded"
    end
  end

  def backfill_products
    say_with_time "backfilling products.search_name/search_terms" do
      select_rows(<<~SQL).each do |id, *fields|
        SELECT id, name, slug, short_description, strength, dosage_form, manufacturer, sku, barcode
        FROM products ORDER BY id
      SQL
        execute(<<~SQL)
          UPDATE products SET search_name = #{quote(normalize(fields.first))},
                              search_terms = #{quote(normalize(fields.compact.join(" ")))}
          WHERE id = #{Integer(id)}
        SQL
      end
    end
  end

  def backfill_lookup(table)
    say_with_time "backfilling #{table}.search_name" do
      select_rows("SELECT id, #{NORMALIZED_LOOKUPS.fetch(table)} FROM #{table} ORDER BY id").each do |id, value|
        execute("UPDATE #{table} SET search_name = #{quote(normalize(value))} WHERE id = #{Integer(id)}")
      end
    end
  end

  def replace_export_types(types)
    existing = connection.check_constraints(:report_export_events).find { |c| c.name == EXPORT_CONSTRAINT }
    remove_check_constraint :report_export_events, name: EXPORT_CONSTRAINT if existing
    add_check_constraint :report_export_events,
      "report_type IN (#{types.map { |type| connection.quote(type) }.join(',')})", name: EXPORT_CONSTRAINT
  end

  def select_rows(sql) = connection.select_rows(sql)
  def quote(value) = connection.quote(value)
  def normalize(value) = Search::ArabicNormalizer.normalize(value)
end
