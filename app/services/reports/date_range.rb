module Reports
  class DateRange
    MAX_DAYS = 366
    Result = Data.define(:start_at, :end_at, :preset, :valid?, :error) do
      def range = start_at...end_at
      def days = ((end_at - start_at) / 1.day).ceil
    end

    def self.call(params, now: Time.current, max_days: MAX_DAYS)
      new(params, now:, max_days:).call
    end

    def initialize(params, now:, max_days:)
      @params, @now, @max_days = params, now.in_time_zone("Africa/Cairo"), max_days
    end

    def call
      preset = @params[:preset].presence || "current_month"
      start_local, end_local = boundaries(preset)
      return invalid("invalid_date") unless start_local && end_local && end_local > start_local
      return invalid("range_too_large") if (end_local.to_date - start_local.to_date).to_i > @max_days
      Result.new(start_at: start_local.utc, end_at: end_local.utc, preset:, valid?: true, error: nil)
    rescue ArgumentError, TypeError
      invalid("invalid_date")
    end

    private

    def boundaries(preset)
      day = @now.beginning_of_day
      case preset
      when "today" then [ day, day + 1.day ]
      when "yesterday" then [ day - 1.day, day ]
      when "last_7_days" then [ day - 6.days, day + 1.day ]
      when "last_30_days" then [ day - 29.days, day + 1.day ]
      when "current_month" then [ @now.beginning_of_month, @now.next_month.beginning_of_month ]
      when "previous_month" then [ @now.last_month.beginning_of_month, @now.beginning_of_month ]
      when "current_quarter" then [ @now.beginning_of_quarter, @now.next_quarter.beginning_of_quarter ]
      when "current_year" then [ @now.beginning_of_year, @now.next_year.beginning_of_year ]
      when "custom" then custom_boundaries
      else [ nil, nil ]
      end
    end

    def custom_boundaries
      from = Date.iso8601(@params[:from].to_s)
      to = Date.iso8601(@params[:to].to_s)
      zone = ActiveSupport::TimeZone["Africa/Cairo"]
      [ zone.local(from.year, from.month, from.day), zone.local(to.year, to.month, to.day) + 1.day ]
    end

    def invalid(code) = Result.new(start_at: nil, end_at: nil, preset: @params[:preset], valid?: false, error: code)
  end
end
