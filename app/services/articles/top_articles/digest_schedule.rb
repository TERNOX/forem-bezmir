# frozen_string_literal: true

module Articles
  module TopArticles
    class DigestSchedule
      TIME_ZONE_NAMES = ["Europe/Kyiv", "Kyiv", "Europe/Kiev"].freeze
      TIME_ZONE = begin
        zone = TIME_ZONE_NAMES.filter_map { |name| ActiveSupport::TimeZone[name] }.first
        raise "Kyiv time zone is unavailable" unless zone

        zone.freeze
      end
      RUN_DAY = :monday
      RUN_HOUR = 20
      RUN_MINUTE = 0
      WINDOW = 1.hour

      attr_reader :reference_time

      def initialize(reference_time: Time.zone.now)
        @reference_time = reference_time
      end

      def next_run_at
        local_reference = reference_time.in_time_zone(TIME_ZONE)
        week_start = local_reference.beginning_of_week(RUN_DAY)
        candidate = scheduled_time_from(week_start)

        candidate += 1.week while candidate < local_reference

        candidate.in_time_zone(Time.zone)
      end

      def self.window
        WINDOW
      end

      def self.time_zone
        TIME_ZONE
      end

      def self.scheduled_time_for(reference_time)
        local_reference = reference_time.in_time_zone(TIME_ZONE)
        week_start = local_reference.beginning_of_week(RUN_DAY)
        scheduled_time_from(week_start)
      end

      class << self
        private

        def scheduled_time_from(week_start)
          TIME_ZONE.local(
            week_start.year,
            week_start.month,
            week_start.day,
            RUN_HOUR,
            RUN_MINUTE,
            0,
          )
        end
      end

      private

      def scheduled_time_from(week_start)
        self.class.send(:scheduled_time_from, week_start)
      end
    end
  end
end
