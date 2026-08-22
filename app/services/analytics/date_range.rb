module Analytics
  class DateRange
    attr_reader :from, :to, :timezone

    def self.for(preset:, from: nil, to: nil, timezone: nil)
      zone = ActiveSupport::TimeZone[timezone.presence || Current.organization&.timezone || "Africa/Cairo"] || Time.zone
      today = zone.today
      values = case preset.to_s
      when "today" then [ today, today ]
      when "last_7_days" then [ today - 6.days, today ]
      when "current_month" then [ today.beginning_of_month, today ]
      when "custom" then [ from, to ]
      else [ today - 29.days, today ]
      end
      new(from: values.first, to: values.last, timezone: zone.name)
    end

    def initialize(from: nil, to: nil, timezone: nil)
      @timezone = timezone.presence || Current.organization&.timezone || "Africa/Cairo"
      zone = ActiveSupport::TimeZone[@timezone] || Time.zone
      @to = parse(to, zone)&.end_of_day || zone.now.end_of_day
      @from = parse(from, zone)&.beginning_of_day || (@to - 29.days).beginning_of_day
      raise ArgumentError, "invalid analytics range" if @from > @to || (@to.to_date - @from.to_date).to_i > 366
    end

    def previous
      duration = to - from
      self.class.new(from: (from - duration - 1.second).to_date, to: (from - 1.second).to_date, timezone:)
    end

    private

    def parse(value, zone)
      zone.parse(value.to_s) if value.present?
    rescue ArgumentError
      nil
    end
  end
end
