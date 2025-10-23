# frozen_string_literal: true

module Articles
  module TopArticles
    class PeriodQuery
      EXCLUDED_ORGANIZATION_IDS = [1, 2].freeze
      REACTION_STATUSES = %w[valid confirmed].freeze
      DEFAULT_LIMIT = 7

      def self.call(start_time:, end_time:, limit: DEFAULT_LIMIT)
        new(start_time: start_time, end_time: end_time, limit: limit).article_ids
      end

      def initialize(start_time:, end_time:, limit: DEFAULT_LIMIT)
        @start_time = start_time
        @end_time = end_time
        @limit = (limit.presence || DEFAULT_LIMIT).to_i
      end

      def article_ids
        return [] unless limit.positive?

        reaction_scope
          .group("reactions.reactable_id")
          .order(Arel.sql("COUNT(*) DESC, reactions.reactable_id ASC"))
          .limit(limit)
          .pluck("reactions.reactable_id")
      end

      private

      attr_reader :start_time, :end_time, :limit

      def reaction_scope
        Reaction
          .select("reactions.reactable_id")
          .joins("INNER JOIN articles ON articles.id = reactions.reactable_id")
          .where(reactable_type: "Article")
          .where(status: REACTION_STATUSES)
          .where(category: positive_public_categories)
          .where(created_at: start_time...end_time)
          .where(articles: { published: true })
          .where.not(articles: { organization_id: EXCLUDED_ORGANIZATION_IDS })
      end

      def positive_public_categories
        ReactionCategory.public.filter { |slug| ReactionCategory[slug].positive? }
      end
    end
  end
end
