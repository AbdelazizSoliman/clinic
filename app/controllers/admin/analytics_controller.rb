require "csv"

module Admin
  class AnalyticsController < BaseController
    skip_before_action :authorize_inventory!
    before_action :authorize_analytics!

    def show
      @range = Analytics::DateRange.for(preset: params[:preset], from: params[:from], to: params[:to])
      branches = current_user.admin? ? selected_branches : [ current_branch ].compact
      @metrics = Analytics::ExecutiveSummary.new(range: @range, branches:).call
      @analytics = Analytics::AdvancedSummary.new(range: @range, branches:).call
      respond_to do |format|
        format.html
        format.csv { send_data csv(@metrics.merge(advanced: @analytics)), filename: "analytics-#{@range.from.to_date}-#{@range.to.to_date}.csv" }
      end
    rescue ArgumentError
      redirect_to admin_analytics_path, alert: "نطاق التاريخ غير صالح"
    end

    private

    def authorize_analytics!
      head :not_found unless current_user&.can_view_business_reports?
    end

    def selected_branches
      return [] if params[:branch_id].blank?
      [ Branch.find(params[:branch_id]) ]
    end

    def csv(metrics)
      CSV.generate(headers: true) do |output|
        output << %w[metric value]
        flatten(metrics).each { |key, value| output << [ safe_cell(key), safe_cell(value) ] }
      end
    end

    def safe_cell(value)
      text = value.to_s
      text.match?(/\A[=+\-@]/) ? "'#{text}" : text
    end

    def flatten(value, prefix = nil)
      case value
      when Hash
        value.flat_map { |key, item| flatten(item, [ prefix, key ].compact.join(".")) }
      when Array
        value.each_with_index.flat_map { |item, index| flatten(item, "#{prefix}.#{index}") }
      else
        [ [ prefix, value ] ]
      end
    end
  end
end
