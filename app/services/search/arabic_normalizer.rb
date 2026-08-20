module Search
  # Deterministic, pure text normalization used for search matching only.
  #
  # Stored display text is never modified: normalization output lives in dedicated
  # `search_*` columns and in the parsed query, so Arabic product names keep their
  # exact original spelling everywhere the user sees them.
  module ArabicNormalizer
    module_function

    # Combining marks: tashkeel (fatha..sukun), superscript alef, and the Quranic
    # annotation range. Tatweel (kashida) is a pure display elongation.
    DIACRITICS = /[ؐ-ًؚ-ٰٟۖ-ۭـ]/

    # Letter folding. Follows the same policy as Lucene's Arabic normalizer, which is
    # the long-standing convention for Arabic information retrieval:
    #   - all hamza-carrying alef forms collapse to bare alef
    #   - alef maqsura collapses to ya, and hamza-on-ya to ya
    #   - hamza-on-waw collapses to waw
    #   - ta marbuta collapses to ha (see docs/search.md for the trade-off)
    #   - Persian/Urdu ya and kaf collapse to their Arabic equivalents
    # Letters that are genuinely distinct (gaf, pe, che) are deliberately left alone.
    LETTER_FOLDING = {
      "أ" => "ا", "إ" => "ا", "آ" => "ا", "ٱ" => "ا", "ٲ" => "ا", "ٳ" => "ا",
      "ى" => "ي", "ئ" => "ي", "ی" => "ي", "ۍ" => "ي", "ې" => "ي",
      "ؤ" => "و", "ۆ" => "و", "ۇ" => "و",
      "ة" => "ه",
      "ک" => "ك", "ڪ" => "ك"
    }.freeze

    # Arabic-Indic and extended Arabic-Indic digits. Users routinely type strengths and
    # barcodes with these, so they must fold to ASCII before any identifier comparison.
    DIGIT_FOLDING = ("٠".."٩").zip("0".."9").to_h.merge(("۰".."۹").zip("0".."9").to_h).freeze

    # Punctuation and separators that carry no search meaning. Arabic comma/semicolon/
    # question mark are included alongside their ASCII counterparts.
    PUNCTUATION = /[،؛؟٪-٭۔!-\/:-@\[-`{-~]/

    MAX_LENGTH = 120

    # Full normalization for free-text matching.
    def normalize(value)
      folded(value).gsub(PUNCTUATION, " ").squish
    end

    # Identifier normalization: keeps SKU punctuation such as the dash in DEMO-001,
    # folds digits and case, and drops only whitespace. Never fuzzy.
    def normalize_identifier(value)
      folded(value).gsub(/[[:space:]]+/, "")
    end

    def tokenize(value)
      normalize(value).split(" ").reject(&:empty?).uniq
    end

    def folded(value)
      text = value.to_s
      return "" if text.empty?

      text = text.unicode_normalize(:nfkc).slice(0, MAX_LENGTH)
      text = text.gsub(DIACRITICS, "")
      text = text.gsub(/[#{Regexp.escape(LETTER_FOLDING.keys.join)}]/) { |char| LETTER_FOLDING.fetch(char) }
      text = text.gsub(/[#{Regexp.escape(DIGIT_FOLDING.keys.join)}]/) { |char| DIGIT_FOLDING.fetch(char) }
      text.downcase
    end
  end
end
