class PrescriptionFilesController < ApplicationController
  before_action :authenticate_user!

  def show
    order = current_user.orders.find_by!(number: params[:order_number])
    prescription = order.prescription
    attachment = prescription&.images_attachments&.find(params[:attachment_id])
    return head :not_found unless attachment

    send_data attachment.blob.download, filename: attachment.filename.to_s, type: attachment.content_type, disposition: "attachment"
  end
end
