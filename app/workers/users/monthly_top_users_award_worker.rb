# frozen_string_literal: true

module Users
  class MonthlyTopUsersAwardWorker
    include Sidekiq::Worker

    sidekiq_options queue: :scheduler

    def perform
      schedule = Users::MonthlyTopUsersSchedule.new
      period = schedule.current_period

      return unless schedule.due?(period)

      Users::CalculateMonthlyReputation.call(period: period)
    end
  end
end
