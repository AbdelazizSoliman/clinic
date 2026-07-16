module Prescriptions
  class AttachmentValidator
    def self.call(files)
      files = Array(files).compact_blank
      errors = []
      errors << "يجب إرفاق صورة أو ملف روشتة" if files.empty?
      errors << "الحد الأقصى 5 ملفات" if files.length > Prescription::MAX_FILES
      files.each do |file|
        errors << "نوع ملف الروشتة غير مدعوم" unless Prescription::ALLOWED_CONTENT_TYPES.include?(file.content_type)
        errors << "امتداد ملف الروشتة غير مدعوم" unless Prescription::ALLOWED_EXTENSIONS.include?(File.extname(file.original_filename).downcase)
        errors << "حجم ملف الروشتة يجب ألا يتجاوز 8 ميجابايت" if file.size > Prescription::MAX_FILE_SIZE
        errors << "ملف الروشتة فارغ" if file.size.zero?
        errors << "محتوى ملف الروشتة لا يطابق نوعه" unless Uploads::FileSignature.valid?(file.tempfile, file.content_type)
      end
      errors.uniq
    end
  end
end
