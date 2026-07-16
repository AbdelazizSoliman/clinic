module ApplicationHelper
  def order_status_label(order) = I18n.t("orders.statuses.#{order.status}")
  def payment_method_label(order) = I18n.t("orders.payment_methods.#{order.payment_method}")
  def payment_status_label(order) = I18n.t("orders.payment_statuses.#{order.payment_status}")
  SORT_OPTIONS = [
    [ "موصى به", "recommended" ], [ "السعر: من الأقل للأعلى", "price_asc" ],
    [ "السعر: من الأعلى للأقل", "price_desc" ], [ "أعلى خصم", "discount_desc" ],
    [ "اسم المنتج", "name" ], [ "الأحدث", "newest" ]
  ].freeze

  def browsing_url(overrides = {})
    values = @active_browsing_params.merge(overrides.stringify_keys).reject { |_key, value| value.blank? || value == "false" }
    "#{@browsing_path}?#{values.to_query}".delete_suffix("?")
  end

  def selected_filter_summary
    pieces = []
    pieces << "منتجات #{@locked_category&.name || Category.find_by(slug: @active_browsing_params["category"])&.name}" if @locked_category || @active_browsing_params["category"].present?
    pieces << Brand.find_by(slug: @active_browsing_params["brand"])&.name if @active_browsing_params["brand"].present?
    pieces << "المتوفرة" if @active_browsing_params["available"] == "true"
    pieces.compact_blank.join(" ").presence || (@active_browsing_params["q"].present? ? "#{@pagy.count} منتجًا مطابقًا لبحثك" : "كل المنتجات")
  end

  def active_filter_chips
    chips = []
    chips << [ "q", "بحث: #{@active_browsing_params["q"]}" ] if @active_browsing_params["q"].present?
    if !@locked_category && @active_browsing_params["category"].present?
      category = Category.find_by(slug: @active_browsing_params["category"])
      chips << [ "category", category.name ] if category
    end
    if @active_browsing_params["brand"].present?
      brand = Brand.find_by(slug: @active_browsing_params["brand"])
      chips << [ "brand", brand.name ] if brand
    end
    chips << [ "min_price", "من #{@active_browsing_params["min_price"]} ج.م" ] if @active_browsing_params["min_price"].present?
    chips << [ "max_price", "حتى #{@active_browsing_params["max_price"]} ج.م" ] if @active_browsing_params["max_price"].present?
    { "discounted" => "عروض فقط", "available" => "متوفر فقط", "prescription" => "يتطلب روشتة", "featured" => "منتجات مميزة" }.each do |key, label|
      chips << [ key, label ] if @active_browsing_params[key] == "true"
    end
    chips
  end

  def pagination_pages
    return (1..@pagy.last).to_a if @pagy.last <= 7

    pages = [ 1, @pagy.page - 1, @pagy.page, @pagy.page + 1, @pagy.last ].select { |page| page.between?(1, @pagy.last) }.uniq.sort
    pages.each_cons(2).flat_map { |first, second| second - first > 1 ? [ first, :gap ] : [ first ] } << pages.last
  end
end
