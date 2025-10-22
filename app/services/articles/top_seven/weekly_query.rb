module Articles
  module TopSeven
    class WeeklyQuery
      EXCLUDED_ORGANIZATION_IDS = [1, 2].freeze
      REACTION_STATUSES = %w[valid confirmed].freeze
      LIMIT = 7

      def self.call(week_start_date)
        new(week_start_date).article_ids
      end

      def initialize(week_start_date)
        @week_start_date = week_start_date.to_date
      end

      def article_ids
        reaction_scope
          .group("reactions.reactable_id")
          .order(Arel.sql("COUNT(*) DESC, reactions.reactable_id ASC"))
          .limit(LIMIT)
          .pluck("reactions.reactable_id")
      end

      private

      attr_reader :week_start_date

      def reaction_scope
        Reaction
          .select("reactions.reactable_id")
          .joins("INNER JOIN articles ON articles.id = reactions.reactable_id")
          .where(reactable_type: "Article")
          .where(status: REACTION_STATUSES)
          .where(category: positive_public_categories)
          .where(created_at: week_range)
          .where(articles: { published: true })
          .where.not(articles: { organization_id: EXCLUDED_ORGANIZATION_IDS })
      end

      def positive_public_categories
        ReactionCategory.public.filter { |slug| ReactionCategory[slug].positive? }
      end

      def week_range
        start_time = Time.zone.local(week_start_date.year, week_start_date.month, week_start_date.day)
        start_time...start_time + 1.week
      end
    end
  end
end
