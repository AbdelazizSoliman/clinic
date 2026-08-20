module Admin
  module Reports
    class ReturnsController < BaseController
      before_action -> { authorize_capability!(:can_view_return_reports?) }
      def index
        @returns = ReturnRequest.where(created_at: @date_range.start_at...@date_range.end_at).includes(:source, :items, :refunds)
        @refund_total = @returns.joins(:refunds).merge(Refund.completed).sum("refunds.amount_cents")
        return unless params[:format] == "csv"
        rows = @returns.flat_map { |record| record.items.map { |item| [ record.number, record.source_type, record.source.number,
          record.created_at.in_time_zone("Africa/Cairo"), item.product_name, item.received_quantity, item.reason,
          item.disposition, item.refundable_amount_cents, record.refunded_cents ] } }
        export = ::Reports::CsvExporter.call(headers: %w[return_number source source_number date product quantity reason disposition refundable_cents refunded_cents], rows:)
        send_data export.content, type: "text/csv; charset=utf-8", filename: "returns.csv"
      end
    end
  end
end
