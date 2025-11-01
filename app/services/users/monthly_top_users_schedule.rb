# frozen_string_literal: true

module Users
  class MonthlyTopUsersSchedule
    def initialize(settings: Settings::General, reference_time: Time.zone.now)
      @settings = settings
      @default_reference_time = reference_time
    end

    def current_period
      Users::CalculateMonthlyReputation.default_period
    end

    def scheduled_time_for(period)
      target_month = period.to_date.beginning_of_month.next_month
      day = normalize_day(settings.monthly_top_users_award_day)
      hour, minute = TimeOfDaySetting.extract_components(settings.monthly_top_users_award_time)
      day = [day, target_month.end_of_month.day].min

      Time.zone.local(target_month.year, target_month.month, day, hour, minute)
    end

    def due?(period = current_period, reference_time: default_reference_time)
      return false if already_awarded?(period)

      reference_time >= scheduled_time_for(period)
    end

    def already_awarded?(period)
      settings.monthly_top_users_last_awarded_period == identifier_for(period)
    end

    def next_run_at
      period = current_period
      if already_awarded?(period)
        scheduled_time_for(period.next_month)
      else
        scheduled_time_for(period)
      end
    end

    def identifier_for(period)
      period.to_date.beginning_of_month.strftime("%Y-%m")
    end

    private

    attr_reader :settings, :default_reference_time

    def normalize_day(value)
      day = value.to_i
      day = 1 if day < 1
      day = 31 if day > 31
      day
    end
  end
end
