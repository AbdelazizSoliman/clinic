module DemoGuidance
  class JourneyCatalog
    Step = Data.define(:title, :description, :scenario, :mode)
    Journey = Data.define(:role, :title, :email, :duration, :summary, :steps, :first_scenario, :two_factor_required)

    DEFINITIONS = {
      customer: {
        title: "رحلة العميل", duration: "4–5 دقائق", first: :catalog, two_factor: false,
        summary: "استكشف المتجر العربي والسلة والتوصيل والطلبات والوصفات المطلوبة.",
        steps: [
          [ "تصفح المنتجات", "استخدم البحث والفلاتر وشاهد حالات التوفر والعروض.", :catalog, :explore ],
          [ "راجع السلة الجاهزة", "الحساب التجريبي يحتوي منتجات وكوبون DEMO10.", :cart, :view ],
          [ "افتح إتمام الطلب", "راجع العنوان والمنطقة والدفع عند الاستلام دون دفع حقيقي.", :checkout, :explore ],
          [ "شاهد طلبًا مكتملًا", "افتح السجل التاريخي ذي الرقم الثابت DEMO-DELIVERED-OLD.", :customer_delivered_order, :view ],
          [ "استكشف منتج وصفة", "شاهد متطلبات الرفع والمراجعة دون تقديم نصيحة طبية.", :prescription_product, :view ]
        ]
      },
      pharmacist: {
        title: "رحلة الصيدلي", duration: "3–4 دقائق", first: :prescription_under_review, two_factor: true,
        summary: "راجع قائمة الوصفات وتأثير القرار على الطلب والحجز دون قرار طبي حقيقي.",
        steps: [
          [ "افتح قائمة المراجعة", "اعرض الوصفات المنتظرة وحالات الفحص.", :pharmacist_queue, :view ],
          [ "افتح المثال قيد المراجعة", "يُحل الطلب DEMO-PRESCRIPTION-REVIEW دون تثبيت رقم قاعدة بيانات.", :prescription_under_review, :view ],
          [ "قارن القرارات السابقة", "شاهد أمثلة الاعتماد والرفض والرسائل الآمنة.", :prescription_examples, :view ],
          [ "اربط الوصفة بالطلب", "لاحظ انتقال حالة الطلب وتحرير أو تمديد الحجز.", :prescription_orders, :view ],
          [ "تنبيه تداخل حرج", "افتح DEMO-SAFETY-INTERACTION وراجع التنبيه الموقف للصرف وتجاوزه الموثق.", :safety_interaction, :view ],
          [ "تعارض حساسية مسجلة", "افتح DEMO-SAFETY-ALLERGY وشاهد تنبيهًا مفتوحًا بانتظار إقرارك.", :safety_allergy, :explore ],
          [ "استبدال ينشئ سياقًا جديدًا", "افتح DEMO-SAFETY-SUBSTITUTION وقارن التقييم القديم بالجديد.", :safety_substitution, :view ],
          [ "نقطة البيع", "شاهد جلسة مفتوحة واعتماد بند دوائي قبل البيع.", :pos_open_session, :explore ]
        ]
      },
      order_manager: {
        title: "رحلة مدير الطلبات والتوصيل", duration: "4–5 دقائق", first: :operations_confirmed, two_factor: true,
        summary: "تتبّع الطلب من التأكيد إلى التجهيز والتوصيل واستهلاك الحجز.",
        steps: [
          [ "طلب مؤكد", "افتح DEMO-CONFIRMED كنقطة بداية تشغيلية.", :operations_confirmed, :view ],
          [ "قيد التجهيز", "قارن DEMO-PREPARING بالحالة المؤكدة.", :operations_preparing, :view ],
          [ "جاهز للتوصيل", "شاهد DEMO-READY بعد استهلاك المخزون المحجوز.", :operations_ready, :view ],
          [ "خرج للتوصيل", "افتح مهمة DEMO-OUT-FOR-DELIVERY المسندة.", :operations_dispatched, :view ],
          [ "إلغاء وتحرير الحجز", "راجع DEMO-CANCELLED كمثال تاريخي لا يحتاج تعديلًا.", :operations_cancelled, :view ],
          [ "إيصال نقطة بيع", "تتبع بيعًا نقديًا مكتملًا وتشغيلاته.", :pos_completed_sale, :view ]
        ]
      },
      inventory_manager: {
        title: "رحلة مدير المخزون", duration: "3–4 دقائق", first: :inventory_dashboard, two_factor: true,
        summary: "افهم المخزون وحركاته ثم اتبع أمر شراء من التوريد إلى الاستلام الجزئي.",
        steps: [
          [ "لوحة المخزون", "قارن الوحدات الفعلية والمحجوزة والمتاحة للبيع.", :inventory_dashboard, :view ],
          [ "المخزون المنخفض والمنعدم", "شاهد المنتجات ذات الرصيد 1 و2 و3 والرصيد صفر.", :inventory_low, :view ],
          [ "سجل الحركات", "راجع الرصيد الافتتاحي وحركات استهلاك الحجوزات.", :inventory_movements, :view ],
          [ "التشغيلات والصلاحية", "قارن التشغيلة المنتهية والقريبة من الصلاحية والمعزولة وتتبع FEFO.", :batch_inventory, :view ],
          [ "تقرير المخزون", "اربط الحالة الحالية ببيانات آخر 30 يومًا.", :inventory_reports, :view ],
          [ "الموردون وأوامر الشراء", "افتح الموردين وقارن المسودة والاعتماد والاستلام الجزئي.", :purchasing_partial, :view ],
          [ "تقرير المشتريات", "راجع القائم والمتأخر وآخر تكلفة شراء.", :purchasing_reports, :view ]
        ]
      },
      admin: {
        title: "رحلة مدير النظام", duration: "4–5 دقائق", first: :admin_users, two_factor: true,
        summary: "استعرض المستخدمين والإعدادات والعروض والتوصيل والتقارير والرقابة الأمنية.",
        steps: [
          [ "المستخدمون والأدوار", "راجع حسابات @example.test وحدود حماية هويات العرض.", :admin_users, :view ],
          [ "إعدادات الصيدلية", "شاهد الملف التشغيلي دون تغيير بيانات العرض أثناء الجولة.", :admin_settings, :view ],
          [ "العرض والكوبون النشطان", "افتح حملة demo:active-cart المرتبطة بكوبون DEMO10.", :admin_promotion, :view ],
          [ "مناطق التوصيل", "قارن الرسوم والحدود والمنطقة المتوقفة.", :admin_delivery, :view ],
          [ "التقارير", "اعرض آخر 30 يومًا لالتقاط الطلب التاريخي المكتمل.", :admin_reports, :view ],
          [ "تقارير نقطة البيع", "راجع طرق الدفع والتسويات وتتبع التشغيلات.", :pos_reports, :view ],
          [ "قواعد سلامة الدواء", "راجع القواعد المُعدّة محليًا وإصداراتها دون تعديل أثناء الجولة.", :safety_rules, :view ],
          [ "تقرير تنبيهات السلامة", "قارن التنبيهات حسب الخطورة والنوع والتجاوزات الموثقة.", :safety_reports, :view ],
          [ "اعتماد المشتريات", "شاهد DEMO-PO-SUBMITTED كأمر ينتظر اعتماد المدير.", :purchasing_submitted, :view ],
          [ "الأمن والتشغيل", "اختم بحالة 2FA والأحداث والتنبيهات التشغيلية.", :admin_security, :view ]
        ]
      }
    }.freeze

    def initialize(user:, resolver:)
      @user = user
      @resolver = resolver
    end

    def call
      DEFINITIONS.map do |role, definition|
        account = DemoData::Accounts::DEFINITIONS.fetch(role)
        steps = definition[:steps].map do |title, description, scenario, mode|
          Step.new(title:, description:, scenario:, mode:)
        end
        Journey.new(role:, title: definition[:title], email: account[:email], duration: definition[:duration],
          summary: definition[:summary], steps:, first_scenario: definition[:first],
          two_factor_required: definition[:two_factor])
      end
    end

    def path_for(step_or_scenario)
      scenario = step_or_scenario.respond_to?(:scenario) ? step_or_scenario.scenario : step_or_scenario
      @resolver.path(scenario)
    end
  end
end
