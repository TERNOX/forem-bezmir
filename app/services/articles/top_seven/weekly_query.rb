module Articles
  module TopSeven
    class WeeklyQuery
      DEFAULT_LIMIT = Articles::TopArticles::PeriodQuery::DEFAULT_LIMIT

      def self.call(week_start_date, limit: DEFAULT_LIMIT)
        new(week_start_date, limit: limit).article_ids
      end

      def initialize(week_start_date, limit: DEFAULT_LIMIT)
        @week_start_date = week_start_date.to_date
        @limit = limit
      end

      def article_ids
        Articles::TopArticles::PeriodQuery.call(
          start_time: week_range.begin,
          end_time: week_range.end,
          limit: limit,
        )
      end

      private

      attr_reader :week_start_date, :limit

      def week_range
        start_time = Time.zone.local(week_start_date.year, week_start_date.month, week_start_date.day)
        start_time...start_time + 1.week
      end
    end
  end
end
