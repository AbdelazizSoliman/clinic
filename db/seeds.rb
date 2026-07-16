# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
# Demo storefront catalog. Upserts make this safe to run repeatedly.
categories = [
  [ "الأدوية والعلاجات", "medicines", "أدوية وعلاجات للاحتياجات الصحية الشائعة", "💊" ],
  [ "الفيتامينات والمكملات", "vitamins-supplements", "فيتامينات ومعادن لدعم صحتك اليومية", "🍊" ],
  [ "العناية بالبشرة", "skin-care", "روتين متكامل لبشرة صحية ونضرة", "✨" ],
  [ "العناية بالأم والطفل", "mother-baby", "منتجات آمنة للأم وطفلها", "🍼" ],
  [ "العناية الشخصية", "personal-care", "أساسيات النظافة والعناية اليومية", "🧴" ],
  [ "الأجهزة والمستلزمات الطبية", "medical-supplies", "أجهزة موثوقة لمتابعة صحتك في المنزل", "🩺" ]
].each_with_index.to_h do |(name, slug, description, icon), position|
  category = Category.find_or_initialize_by(slug: slug)
  category.update!(name: name, description: description, icon: icon, active: true, position: position)
  [ slug, category ]
end

brands = [
  [ "إيفا فارما", "eva-pharma" ], [ "لاروش بوزيه", "la-roche-posay" ],
  [ "فيشي", "vichy" ], [ "سولجار", "solgar" ], [ "بيبي جوي", "baby-joy" ],
  [ "جونسون", "johnsons" ], [ "أورال بي", "oral-b" ], [ "أومرون", "omron" ]
].to_h do |name, slug|
  brand = Brand.find_or_initialize_by(slug: slug)
  brand.update!(name: name, active: true)
  [ slug, brand ]
end

products = [
  [ "بانادول أدفانس 24 قرص", "panadol-advance-24", "مسكن للآلام وخافض للحرارة", 72, 85, 40, true, false, "medicines", "eva-pharma" ],
  [ "كونجستال 20 قرص", "congestal-20", "لتخفيف أعراض البرد والإنفلونزا", 48, nil, 35, false, false, "medicines", "eva-pharma" ],
  [ "أوجمنتين 1 جم 14 قرص", "augmentin-1g", "مضاد حيوي واسع المجال بوصفة طبية", 198, nil, 14, true, true, "medicines", "eva-pharma" ],
  [ "فولتارين إيمولجيل 50 جم", "voltaren-emulgel-50", "جل موضعي لتسكين آلام العضلات", 115, 135, 0, false, false, "medicines", "eva-pharma" ],
  [ "فيتامين سي 1000 مجم", "vitamin-c-1000", "دعم المناعة بمضادات الأكسدة", 285, 330, 28, true, false, "vitamins-supplements", "solgar" ],
  [ "أوميجا 3 زيت السمك", "omega-3-fish-oil", "دعم القلب والمخ في كبسولات سهلة البلع", 495, nil, 18, true, false, "vitamins-supplements", "solgar" ],
  [ "فيتامين د3 1000 وحدة", "vitamin-d3-1000", "دعم صحة العظام والمناعة", 260, 295, 22, false, false, "vitamins-supplements", "solgar" ],
  [ "مالتي فيتامين للنساء", "womens-multivitamin", "تركيبة يومية متوازنة للنساء", 575, nil, 0, false, false, "vitamins-supplements", "solgar" ],
  [ "إيفاكلار جل منظف 200 مل", "effaclar-cleansing-gel", "تنظيف لطيف للبشرة الدهنية والحساسة", 620, 720, 16, true, false, "skin-care", "la-roche-posay" ],
  [ "أنثيليوس واقي شمس SPF50", "anthelios-spf50", "حماية فائقة من الشمس بملمس خفيف", 890, nil, 11, true, false, "skin-care", "la-roche-posay" ],
  [ "فيشي مينيرال 89 سيروم", "vichy-mineral-89", "سيروم يومي مقوٍ ومرطب للبشرة", 1050, 1200, 8, false, false, "skin-care", "vichy" ],
  [ "فيشي مزيل عرق 48 ساعة", "vichy-deodorant-48", "حماية طويلة الأمد للبشرة الحساسة", 475, nil, 20, false, false, "skin-care", "vichy" ],
  [ "حفاضات بيبي جوي مقاس 4", "babyjoy-diapers-size-4", "حفاضات ناعمة بامتصاص يدوم طويلًا", 390, 450, 24, true, false, "mother-baby", "baby-joy" ],
  [ "مناديل مبللة للأطفال 72", "baby-wipes-72", "مناديل لطيفة خالية من الكحول", 95, nil, 32, false, false, "mother-baby", "baby-joy" ],
  [ "زيت جونسون للأطفال 200 مل", "johnsons-baby-oil", "ترطيب لطيف لبشرة الطفل الحساسة", 165, 190, 13, false, false, "mother-baby", "johnsons" ],
  [ "شامبو جونسون للأطفال 500 مل", "johnsons-baby-shampoo", "تركيبة لا دموع لتنظيف الشعر بلطف", 220, nil, 0, false, false, "mother-baby", "johnsons" ],
  [ "فرشاة أورال بي برو فليكس", "oral-b-pro-flex", "تنظيف فعال ولطيف للأسنان واللثة", 145, 175, 26, false, false, "personal-care", "oral-b" ],
  [ "خيط أسنان أورال بي 50 متر", "oral-b-floss-50", "إزالة البلاك بين الأسنان بسهولة", 120, nil, 17, false, false, "personal-care", "oral-b" ],
  [ "غسول فم أورال بي 500 مل", "oral-b-mouthwash", "انتعاش وحماية يومية للفم", 185, 215, 12, true, false, "personal-care", "oral-b" ],
  [ "لوشن جونسون للجسم 400 مل", "johnsons-body-lotion", "ترطيب يومي ناعم للجسم", 210, nil, 19, false, false, "personal-care", "johnsons" ],
  [ "جهاز قياس ضغط أومرون M2", "omron-m2-blood-pressure", "جهاز رقمي دقيق وسهل الاستخدام", 2450, 2800, 7, true, false, "medical-supplies", "omron" ],
  [ "ميزان حرارة رقمي أومرون", "omron-digital-thermometer", "قياس سريع ودقيق لدرجة الحرارة", 320, nil, 15, false, false, "medical-supplies", "omron" ],
  [ "جهاز نيبولايزر أومرون C101", "omron-c101-nebulizer", "جهاز استنشاق منزلي فعال", 1750, 1950, 5, false, false, "medical-supplies", "omron" ],
  [ "شرائط اختبار سكر 50 شريط", "glucose-test-strips-50", "شرائط قياس للاستخدام المنزلي", 450, nil, 0, false, false, "medical-supplies", "omron" ]
]

products.each_with_index do |(name, slug, short_description, price, compare_at_price, stock, featured, prescription, category_slug, brand_slug), index|
  product = Product.find_or_initialize_by(slug: slug)
  product.update!(
    name: name, short_description: short_description,
    description: "#{short_description}. منتج أصلي من #{brands.fetch(brand_slug).name}. يُحفظ في مكان جاف بعيدًا عن أشعة الشمس ومتناول الأطفال.",
    price: price, compare_at_price: compare_at_price, stock_quantity: stock,
    featured: featured, requires_prescription: prescription, active: true,
    category: categories.fetch(category_slug), brand: brands.fetch(brand_slug),
    sku: format("PH-%04d", index + 1), barcode: format("622000%06d", index + 1), low_stock_threshold: 5,
    maximum_order_quantity: 10, published_at: product.published_at || Time.current
  )
  if stock.positive?
    product.inventory_movements.find_or_create_by!(idempotency_key: "seed-opening-#{slug}") do |movement|
      movement.assign_attributes(movement_type: :opening_balance, quantity_delta: stock, quantity_before: 0,
        quantity_after: stock, reason: "رصيد افتتاحي من بيانات العرض")
    end
  end
end

puts "Seeded #{Category.count} categories, #{Brand.count} brands, and #{Product.count} products."
