require "test_helper"

class Search::ArabicNormalizerTest < ActiveSupport::TestCase
  Normalizer = Search::ArabicNormalizer

  test "all hamza-carrying alef forms fold to bare alef" do
    %w[أحمد إحمد آحمد ٱحمد].each { |spelling| assert_equal "احمد", Normalizer.normalize(spelling) }
    assert_equal "احمد", Normalizer.normalize("احمد")
  end

  test "diacritics and tatweel are ignored" do
    assert_equal "اقراص", Normalizer.normalize("أَقْراص")
    assert_equal "مسكن", Normalizer.normalize("مُسَكِّن")
    assert_equal "دوا", Normalizer.normalize("دوـــا")
  end

  test "alef maqsura and hamza carriers fold to their base letters" do
    assert_equal "اليومي", Normalizer.normalize("اليومى")
    assert_equal "مسيول", Normalizer.normalize("مسئول")
    assert_equal "سوال", Normalizer.normalize("سؤال")
  end

  test "persian ya and kaf variants fold to the arabic letters" do
    assert_equal Normalizer.normalize("يكي"), Normalizer.normalize("یکی")
  end

  # Documented deliberate policy: ta marbuta folds to ha, following the long-standing
  # Arabic IR convention, so "حراره" and "حرارة" are the same search term.
  test "ta marbuta folds to ha by design" do
    assert_equal "حراره", Normalizer.normalize("حرارة")
    assert_equal Normalizer.normalize("حرارة"), Normalizer.normalize("حراره")
  end

  test "latin text is lowercased and whitespace is collapsed" do
    assert_equal "panadol advance", Normalizer.normalize("  Panadol   ADVANCE  ")
    assert_equal "panadol 500mg", Normalizer.normalize("Panadol 500MG!")
  end

  test "arabic-indic digits fold to ascii" do
    assert_equal "500", Normalizer.normalize("٥٠٠")
    assert_equal "500", Normalizer.normalize("۵۰۰")
  end

  test "mixed arabic and english queries tokenize safely" do
    assert_equal %w[بانادول 500 mg], Normalizer.tokenize("بانادول ٥٠٠ MG")
    assert_equal [ "فيتامين", "c" ], Normalizer.tokenize("فيتامين C")
  end

  test "identifier normalization keeps sku punctuation and drops spaces" do
    assert_equal "demo-001", Normalizer.normalize_identifier(" DEMO-٠٠١ ")
    assert_equal "622000000001", Normalizer.normalize_identifier("622 000 000 001")
  end

  test "input is bounded and empty input is safe" do
    assert_equal "", Normalizer.normalize(nil)
    assert_equal "", Normalizer.normalize("   ")
    assert_operator Normalizer.normalize("ا" * 500).length, :<=, Search::ArabicNormalizer::MAX_LENGTH
  end

  test "normalization never mutates stored display text" do
    product = products(:featured)
    original = product.name
    product.save!
    assert_equal original, product.reload.name
    assert_not_equal original, product.search_name
  end
end
