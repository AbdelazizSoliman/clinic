# Advanced Arabic search — Phase 21

Phase 21 replaces four duplicated `ILIKE` fragments with one PostgreSQL-native product
search domain that understands Arabic spelling variation, mixed Arabic/English input,
structured active ingredients and operational identifiers.

No external search service is involved. There is no Elasticsearch, OpenSearch, Algolia,
Meilisearch, Typesense, external API, embedding model or AI of any kind: the whole engine
is PostgreSQL plus `pg_trgm`.

## What existed before

| Context | Implementation | Behaviour |
| --- | --- | --- |
| Storefront | `ProductsQuery#search` | `ILIKE '%q%'` over name/short_description/brand/category |
| POS | `Pos::ProductsController` | exact `barcode`/`sku` plus `ILIKE`, ordered by a quoted CASE |
| Admin | `Admin::ProductsQuery` | `ILIKE` over name/sku/barcode |
| Substitution | none | a `<select>` listing every allocatable prescription product |

There was no normalization of any kind, no trigram or full-text index, and `pg_trgm` was
not installed. A customer searching `اقراص` could not find `أقراص`.

## Architecture

```
Search::Query            parse, bound, tokenize, expand synonyms
   → Search::ArabicNormalizer   deterministic pure text folding
   → Search::Products           context-aware relation + deterministic ranking
   → Search::Result             bounded, ordered records + exact-identifier flag
   → Search::RecordEvent        privacy-conscious aggregate analytics
```

`Search::Lookups` supplies brand/category/ingredient suggestions. `Searchable` (a model
concern) maintains the normalized columns. Nothing else in the application builds product
search SQL.

## Normalization policy

Normalization is used **only** for matching. Display text is never altered: the projections
live in dedicated `search_*` columns, and every rendered product name is the original.

| Rule | Example |
| --- | --- |
| Strip tashkeel and Quranic marks | `أَقْراص` → `اقراص` |
| Strip tatweel/kashida | `دوـــا` → `دوا` |
| `أ إ آ ٱ ٲ ٳ` → `ا` | `إبراهيم` → `ابراهيم` |
| `ى ئ ی ۍ ې` → `ي` | `اليومى` → `اليومي` |
| `ؤ ۆ ۇ` → `و` | `سؤال` → `سوال` |
| `ة` → `ه` | `حرارة` → `حراره` |
| `ک ڪ` → `ك` | Persian/Urdu kaf |
| Arabic-Indic digits → ASCII | `٥٠٠` and `۵۰۰` → `500` |
| Lowercase, collapse whitespace, drop punctuation | `  Panadol  500MG! ` → `panadol 500mg` |

**On `ة` → `ه`:** this is applied deliberately. It follows the long-standing Arabic IR
convention (the same folding Lucene's Arabic normalizer performs) and matters here because
Egyptian product names are routinely typed both ways (`حرارة` / `حراره`, `كبسولة` /
`كبسوله`). The cost is that a small number of unrelated words collide (`مرة` and `مره`).
On a pharmacy catalogue of short product names that trade is clearly worth it; the folding
is a single entry in `LETTER_FOLDING` and can be removed without touching anything else.

Genuinely distinct letters — gaf, pe, che — are **not** folded. No transliteration between
Arabic and Latin is performed: the repository has no transliteration data to justify it.

Identifiers use a separate rule (`normalize_identifier`): digits and case fold, whitespace
is dropped, but SKU punctuation such as the dash in `DEMO-001` is preserved. Identifiers
are never fuzzy-matched.

Queries are capped at 120 characters and 8 tokens before any SQL is built.

## Exact identifier behaviour

Operational identifiers are pinned above every textual match by construction — they are
ranking tiers 0 and 1, and no similarity score can promote a record past them.

1. exact `barcode`
2. exact `sku` (case-insensitive, via the `upper(sku)` expression index)
3. exact normalized name
4. normalized name prefix
5. all tokens present in the product's own text
6. all tokens satisfied across product text, brand, category or active ingredient
7. `word_similarity` fuzzy match

Ties break on similarity descending, then `search_name`, then `id` — never on
database-dependent ordering. `Result#exact_identifier_match` reports when the top hit was an
identifier resolution, which POS renders as an explicit "exact match" badge.

A barcode is only ever compared with `=`. Scanning stays a lookup, not a fuzzy search.

## Searchable fields

`products.search_terms` projects the product's **own** columns only: name, slug,
short_description, strength, dosage_form, manufacturer, sku, barcode. Brand, category and
active ingredient are matched through `EXISTS` subqueries against their own normalized
columns.

Because a product never stores another record's text, a plain `before_save` keeps every
projection correct: renaming a brand can never leave a product's projection stale, and no
cross-record invalidation logic exists. `EXISTS` also means a product can never be
duplicated by a join, so no `DISTINCT` is needed.

Private and internal fields — `description`, internal notes, cost price, clinical notes —
are never searched.

## Token matching

Tokens are combined with AND, but each token may be satisfied by a *different* field. So
`بانادول إيفا` matches when the name carries one token and the brand carries the other, and
`ألفازين 500` matches when an ingredient carries one and the strength carries the other.
Synonym expansions are added to the token set (one hop only, capped at 4).

## Typo tolerance

Fuzzy matching uses `word_similarity(query, products.search_name)` — the similarity of the
query against the best matching *word extent* of the name — not whole-string `similarity`.
Measured on this catalogue:

| Query vs stored name | `similarity` | `word_similarity` |
| --- | --- | --- |
| `بانادول` vs `بانادول ادفانس 24 قرص` | 0.36 | **1.00** |
| `بنادول` (one char missing) | 0.21 | **0.57** |
| `فتامين` vs `فيتامين ج 500 مجم 30 قرص` | 0.19 | **0.57** |
| `كريم` vs `مرطب يومي للبشره` | 0.00 | **0.00** |

Whole-string `similarity` is unusable here — a *correct* one-word query against a long
product name scores only 0.32. The threshold is **0.5**, which accepts a one-character
error and rejects unrelated names, and fuzzy matching is only offered for queries of 4
characters or more so short queries never generate trigram noise.

## Active ingredient search

Searching an ingredient name matches products through
`product_active_ingredients → active_ingredients.search_name`, using the Phase 20 structured
identity. Inactive links and inactive ingredients stop matching. The legacy free-text
`products.active_ingredient` column is display metadata and is deliberately **not** used as
clinical identity.

## Context-specific filtering

| Context | Base relation | Extra |
| --- | --- | --- |
| `storefront` / `suggestion` | `Product.publicly_available` | active product, active brand and category |
| `pos` | `Product.active` | shows unsellable stock states so the cashier can see *why* a product cannot be sold |
| `substitution` | `Product.active.where(requires_prescription: true)` | `EXISTS` allocatable batch: not quarantined, not expired, on-hand above reserved |
| `staff` | `Product.all` | inactive products are visible and labelled |

## Integration

**Storefront.** `ProductsQuery` delegates to the service and keeps its entire
category/brand/price/boolean-filter/pagination pipeline. Relevance ordering applies only to
the default "recommended" sort; an explicit sort (price, name, newest, discount) always
wins. Browsing with no query is completely untouched.

**Suggestions.** A public, debounced combobox on the header search field returns at most 6
products plus brand/category/ingredient shortcuts, rendered server-side. It is keyboard
navigable (arrow keys, Enter, Escape), uses `role="combobox"`/`role="listbox"` with
`aria-activedescendant`, and shows only publicly available products.

**POS.** The existing barcode field and keyboard workflow are unchanged. The text search
now routes through the service, flags exact identifier hits, and states plainly when an
identifier is not found. Nothing about stock, prescription or safety enforcement changed.

**Prescription substitution.** The full `<select>` of every allocatable prescription product
is replaced by a pharmacist-only search panel that renders radio options inside the existing
decision form. The endpoint's own copy states that search does not rank substitutes
clinically. Selection still flows through `Prescriptions::DecideLine`, which re-runs the
Phase 20 safety evaluation and keeps every Phase 19 guard — a regression test asserts that a
product surfaced by search still cannot bypass a blocking finding or an availability guard.

**Drug safety administration.** `Admin::ActiveIngredientsController` reuses
`Search::ArabicNormalizer` for ingredient lookup so admins get the same Arabic tolerance,
without coupling clinical rule administration to the public product-search service.

## PostgreSQL and index strategy

`pg_trgm` is enabled by migration (verified creatable by the application role). Normalization
runs in Ruby into stored columns rather than in SQL or a generated column: a generated column
would need an `IMMUTABLE` SQL implementation of the folding table and could only be changed by
dropping and recreating the column, whereas the Ruby normalizer is directly unit-testable and
a policy change is a backfill. No product data is duplicated into a search table.

| Index | Rationale |
| --- | --- |
| `products.search_name` GIN trgm | prefix pass and fuzzy pass; a B-tree cannot serve `LIKE '%…%'` |
| `products.search_terms` GIN trgm | multi-token `LIKE '%token%'` pass |
| `products (upper(sku))` B-tree | case-insensitive exact SKU |
| `products.barcode` unique B-tree | already existed; exact barcode |
| `brands/categories/active_ingredients.search_name` GIN trgm | the `EXISTS` lookup passes |
| `search_events` on context/fingerprint/zero_result + created_at | the three report groupings |

## Measured performance

`EXPLAIN (ANALYZE, BUFFERS)` on the development dataset (52 products, 13 brands):

| Query | Execution time | Plan |
| --- | --- | --- |
| exact barcode (POS) | 1.7 ms | single query, sort of 1 row |
| exact SKU (POS) | 4.5 ms | single query |
| Arabic single token | 1.4 ms | single query |
| Arabic typo (fuzzy) | 1.3 ms | single query |
| multi-token Arabic + English | 4.9 ms | single query |
| ingredient (substitution) | 0.8 ms | single query |

At this size PostgreSQL correctly prefers sequential scans — a 52-row table is cheaper to
scan than to index — so these numbers demonstrate correctness and the absence of N+1, not
index usage. Index *usability* was verified separately with `SET enable_seqscan = off`:

```
search_terms token   -> Bitmap Index Scan on index_products_on_search_terms_trgm
search_name prefix   -> Bitmap Index Scan on index_products_on_search_name_trgm
upper(sku) exact     -> Index Scan using index_products_on_upper_sku
barcode exact        -> Index Scan using index_products_on_barcode
brand search_name    -> Bitmap Index Scan on index_brands_on_search_name_trgm
```

Every search is a single query; POS and substitution results preload their associations. No
capacity or throughput claim is made beyond these measurements.

## Synonyms

`SearchSynonym` is a small admin-managed table (`term → expansion`, both stored normalized).
Expansion is one hop only and capped at 4 additions, so the token set stays bounded and
predictable. The demo set is purely linguistic: singular/plural and a common misspelling.

Synonyms widen what a query can **find**. They never assert that two medicines are
interchangeable, they are not consulted by the drug safety engine or by substitution logic,
and the admin form says so explicitly.

## Search analytics and reporting

`SearchEvent` records one row per executed search: context, normalized query text, an
irreversible fingerprint, token count, result count, zero-result flag, and the selected
product when known.

Privacy decisions:

- **No user, session, IP or actor column exists** — a test asserts the schema has none.
- The `substitution` context stores **no query text at all**, only the fingerprint: those
  queries are typed while a specific patient's prescription is on screen. A model validation
  and a test enforce this.
- Query text is bounded to 120 characters by a check constraint.
- Recording is best-effort and never blocks or slows a search, a sale or a clinical decision.
- Only the first page of a search is recorded, so paging does not inflate counts.

`/admin/reports/search` (admins and order managers) shows top queries, zero-result queries,
counts by context, products selected after a search, and the selection ratio. CSV export is
aggregate — one row per distinct normalized query, never per event. These are operational
metrics about what was typed; no claim is made about customer intent beyond that.

## Security and privacy

- Every value reaches PostgreSQL as a bound parameter via `where(template, *values)`. The one
  exception is the ORDER BY relevance expression, which PostgreSQL cannot parameterize; it is
  built by `sanitize_sql_array` from frozen literal templates and is covered by
  `test/services/search/injection_safety_test.rb`, which fires quote, wildcard, comment and
  UNION payloads and asserts no data changes. The corresponding Brakeman warning is recorded
  as reviewed in `config/brakeman.ignore` with that justification.
- `LIKE` wildcards in user input are escaped with `sanitize_sql_like`; a test asserts `%%%%`
  cannot widen a match.
- All output is rendered through normal ERB escaping. No highlighting is implemented, so no
  string is ever marked `html_safe` — correctness was preferred over highlighting.
- Authorization is applied before results in every context: suggestions expose only publicly
  available products, POS search requires POS authorization, and the substitution lookup is
  pharmacist-only (verified against direct HTTP requests for every other role).
- Query length, token count and result limits are all bounded server-side.

## Limitations

- No transliteration between Arabic and Latin script (`panadol` will not find `بانادول`
  unless the latin form appears in the product's slug or manufacturer).
- No stemming, root extraction or definite-article stripping: `اليومي` does not match a
  product named only `يومي`.
- Fuzzy matching runs as a filter, not an index probe, because our 0.5 word-similarity
  threshold is looser than pg_trgm's operator default of 0.6. On a single-pharmacy catalogue
  this is measured at low single-digit milliseconds; a much larger catalogue would want a
  session-level `word_similarity_threshold` so the `<%` operator can use the GIN index.
- Normalized projections are maintained by model callbacks, so a bulk `update_all` on a name
  would bypass them. Fixtures spell the projections out explicitly for the same reason.
- Suggestions are product/brand/category/ingredient only — no query-history suggestions.
- Search analytics measure queries and result counts, not customer intent or conversion.

## Phase 22 boundary

Deferred: transliteration, stemming/lemmatization, query-history suggestions, per-user
personalization, ranking weights tuned on real traffic, and index-assisted fuzzy matching via
a session-level similarity threshold. Permanently out of scope: external search services,
vector or semantic embeddings, generative AI search, recommendations, voice and image search.

## Tenant isolation

Products, ingredients, synonyms and search events are organization-owned and centrally scoped. Suggestions and all storefront/POS/substitution results therefore exclude other tenants even for guessed stable IDs. Search events also retain the verified branch context, so reports and aggregate CSV honor staff branch access; historical rows were backfilled to their organization's deterministic default branch.
