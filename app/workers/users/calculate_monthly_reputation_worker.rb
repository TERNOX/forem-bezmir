module Users
  class CalculateMonthlyReputationWorker
    include Sidekiq::Worker

    sidekiq_options queue: :low

    def perform(period = nil)
      parsed_period = parse_period(period)
      Users::CalculateMonthlyReputation.call(period: parsed_period)
    end

    private

    def parse_period(period)
      return Users::CalculateMonthlyReputation.default_period if period.blank?

      Date.parse(period).beginning_of_month
    rescue ArgumentError
      Users::CalculateMonthlyReputation.default_period
    end
  end
end
