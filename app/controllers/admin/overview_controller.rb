module Admin
  class OverviewController < Admin::ApplicationController
    layout "admin"
    def index
    end

    def stats
      period = (params[:period] || 7).to_i
      period = [7, 30, 90, 365].include?(period) ? period : 7

      time_range = build_time_range(params[:start_date], params[:end_date])
      stats = if time_range
                Admin::StatsData.new(time_range: time_range).call
              else
                Admin::StatsData.new(period: period).call
              end

      render json: stats
    end

    private

    def build_time_range(start_date, end_date)
      return unless start_date.present? && end_date.present?

      parsed_start = Time.zone.parse(start_date)&.to_date
      parsed_end = Time.zone.parse(end_date)&.to_date
      return unless parsed_start && parsed_end
      return if parsed_end < parsed_start

      parsed_start.beginning_of_day..parsed_end.end_of_day
    end
  end
end
