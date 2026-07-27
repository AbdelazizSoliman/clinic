module Admin
  class PurchaseOrdersController < BaseController
    before_action :set_purchase_order, except: %i[index new create]

    def index
      scope = PurchaseOrder.includes(:supplier, :created_by, :approved_by)
      scope = scope.where(status: params[:status]) if PurchaseOrder.statuses.key?(params[:status])
      scope = scope.where(supplier_id: params[:supplier_id]) if params[:supplier_id].present?
      if params[:q].present?
        term = "%#{PurchaseOrder.sanitize_sql_like(params[:q])}%"
        scope = scope.joins(:supplier).where("purchase_orders.number ILIKE :term OR suppliers.name ILIKE :term OR suppliers.code ILIKE :term", term:)
      end
      @pagy, @purchase_orders = pagy(scope.order(created_at: :desc), limit: 20)
    end
    def new = @purchase_order = PurchaseOrder.new(expected_at: Date.current + 7.days)
    def edit
      redirect_to(admin_purchase_order_path(@purchase_order), alert: "لا يمكن تعديل أمر بعد إرساله") unless @purchase_order.draft?
    end
    def show
      @events = @purchase_order.events.includes(:actor).order(:created_at)
      @receipts = @purchase_order.receipts.includes(items: { purchase_order_item: :product }).order(:received_at)
      @idempotency_key = SecureRandom.uuid if @purchase_order.receivable?
      if params[:product_q].present? && @purchase_order.draft?
        term = "%#{Product.sanitize_sql_like(params[:product_q])}%"
        @product_results = Product.active.where("name ILIKE :term OR sku ILIKE :term OR barcode ILIKE :term", term:)
          .where.not(id: @purchase_order.items.select(:product_id)).order(:name).limit(20)
      else
        @product_results = Product.none
      end
    end

    def create
      supplier = Supplier.find_by(id: purchase_order_params[:supplier_id])
      result = Purchasing::CreateOrder.new(actor: current_user, supplier:,
        attributes: purchase_order_params.except(:supplier_id, :lock_version)).call
      if result.success?
        redirect_to admin_purchase_order_path(result.purchase_order), notice: "تم إنشاء مسودة أمر الشراء"
      else
        @purchase_order = result.purchase_order || PurchaseOrder.new(purchase_order_params)
        @purchase_order.errors.add(:base, result.errors.join("، "))
        render :new, status: :unprocessable_entity
      end
    end

    def update
      result = Purchasing::UpdateDraft.new(purchase_order: @purchase_order, actor: current_user,
        attributes: purchase_order_params.except(:supplier_id, :lock_version), lock_version: purchase_order_params[:lock_version]).call
      if result.success?
        redirect_to admin_purchase_order_path(@purchase_order), notice: "تم تحديث المسودة"
      else
        @purchase_order.errors.add(:base, result.errors.join("، "))
        render :edit, status: :unprocessable_entity
      end
    end

    %i[submit approve close].each do |action|
      define_method(action) do
        service = "Purchasing::#{action.to_s.classify}".constantize
        result = service.new(purchase_order: @purchase_order, actor: current_user, lock_version: params[:lock_version]).call
        redirect_to admin_purchase_order_path(@purchase_order), status: :see_other,
          flash: { result.success? ? :notice : :alert => result.success? ? transition_notice(action) : result.errors.join("، ") }
      end
    end

    def cancel
      result = Purchasing::Cancel.new(purchase_order: @purchase_order, actor: current_user,
        reason: params[:reason], lock_version: params[:lock_version]).call
      redirect_to admin_purchase_order_path(@purchase_order), status: :see_other,
        flash: { result.success? ? :notice : :alert => result.success? ? "تم إلغاء أمر الشراء دون عكس أي استلام سابق" : result.errors.join("، ") }
    end

    def destroy
      return redirect_to(admin_purchase_order_path(@purchase_order), alert: "يمكن حذف مسودة فارغة فقط") unless @purchase_order.draft? && @purchase_order.items.none? && @purchase_order.events.size <= 1
      @purchase_order.events.delete_all
      @purchase_order.destroy!
      redirect_to admin_purchase_orders_path, notice: "تم حذف المسودة الفارغة"
    end

    private

    def set_purchase_order = @purchase_order = PurchaseOrder.includes(items: :product).find_by!(number: params[:number])
    def purchase_order_params
      params.require(:purchase_order).permit(:supplier_id, :expected_at, :notes, :internal_notes, :lock_version)
    end
    def transition_notice(action) = { submit: "تم إرسال أمر الشراء للاعتماد", approve: "تم اعتماد أمر الشراء", close: "تم إغلاق أمر الشراء" }.fetch(action)
  end
end
