module Reports
  class AsyncExporter
    Result = Data.define(:success?, :export, :error)

    def self.call(user:, report_type:, filters:)
      type = report_type.to_s
      safe_filters = filters.to_h.stringify_keys.slice("preset", "from", "to", "status", "category_id", "brand_id", "zone_id")
      return Result.new(success?: false, export: nil, error: :unauthorized) unless authorized?(user, type)
      return Result.new(success?: false, export: nil, error: :too_many_active) if user.report_exports.active.count >= ReportExport::MAX_ACTIVE_PER_USER

      key = Digest::SHA256.hexdigest([ user.id, type, safe_filters.sort ].to_json)
      existing = user.report_exports.active.find_by(deduplication_key: key)
      return Result.new(success?: true, export: existing, error: nil) if existing

      export = user.report_exports.create!(report_type: type, filters: safe_filters,
        status: :pending, requested_at: Time.current, deduplication_key: key)
      GenerateExportJob.perform_later(export.id)
      Result.new(success?: true, export:, error: nil)
    rescue ActiveRecord::RecordNotUnique
      retry
    end

    def self.authorized?(user, type)
      return false unless user&.active? && user.can_export_reports? && ReportExport::TYPES.include?(type)
      case type
      when "inventory" then user.can_view_inventory_reports?
      when "prescriptions" then user.can_view_prescription_reports?
      when "fulfilments", "sales", "orders" then user.can_view_business_reports?
      when "customers", "promotions" then user.admin?
      when "products" then user.can_view_business_reports? || user.can_view_inventory_reports?
      else false
      end
    end
  end
end
