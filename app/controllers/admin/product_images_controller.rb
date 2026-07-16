module Admin
  class ProductImagesController < BaseController
    before_action :set_product
    def create
      image = @product.images.build(alt_text: params[:alt_text], position: @product.images.maximum(:position).to_i + 1, primary: @product.images.none?)
      image.file.attach(params[:file])
      if image.save
        AdminAuditEvent.create!(actor: current_user, auditable: @product, action: "product_image_added", change_data: { image_id: image.id })
        redirect_to admin_product_path(@product), notice: "تمت إضافة الصورة"
      else
        redirect_to admin_product_path(@product), alert: image.errors.full_messages.join("، ")
      end
    end
    def destroy
      image = @product.images.find(params[:id])
      image.destroy!
      redirect_to admin_product_path(@product), notice: "تم حذف الصورة"
    end
    def set_primary
      image = @product.images.find(params[:id])
      ProductImage.transaction do
        @product.images.update_all(primary: false)
        image.update!(primary: true)
      end
      redirect_to admin_product_path(@product), notice: "تم تعيين الصورة الرئيسية"
    end
    private
    def set_product = @product = Product.find_by!(slug: params[:product_id])
  end
end
