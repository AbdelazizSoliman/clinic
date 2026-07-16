module Staff
  class PrescriptionFilesController < BaseController
    before_action :authorize_review!

    def show
      prescription = Prescription.find(params[:prescription_id])
      attachment = prescription.images_attachments.find(params[:attachment_id])
      disposition = attachment.content_type.start_with?("image/") ? "inline" : "attachment"
      send_data attachment.blob.download, filename: attachment.filename.to_s, type: attachment.content_type, disposition:
    end

    private

    def authorize_review!
      head :not_found unless current_user.can_review_prescriptions?
    end
  end
end
