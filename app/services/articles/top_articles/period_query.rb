# frozen_string_literal: true

module Articles
  module TopArticles
    class PeriodQuery
      DEFAULT_EXCLUDED_ORGANIZATION_IDS = [1, 2].freeze
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
          .group("reactions.reactable_id, #{article_score_expression}")
          .order(Arel.sql("#{article_score_expression} DESC, COUNT(*) DESC, reactions.reactable_id ASC"))
          .limit(limit)
          .pluck("reactions.reactable_id")
      end

      private

      attr_reader :start_time, :end_time, :limit

      def reaction_scope
        scope = Reaction
          .select("reactions.reactable_id")
          .joins("INNER JOIN articles ON articles.id = reactions.reactable_id")
          .where(reactable_type: "Article")
          .where(status: REACTION_STATUSES)
          .where(category: positive_public_categories)
          .where(created_at: start_time...end_time)
          .where(articles: { published: true })
          .where(articles: { published_at: start_time...end_time })
          .where.not(articles: { type_of: Article.type_ofs[:status] })
          .where("#{article_score_expression} >= ?", minimum_score)

        if (predicate = organization_filter_predicate)
          scope = scope.where(predicate)
        end

        if (predicate = excluded_tags_predicate)
          scope = scope.where(predicate)
        end

        scope
      end

      def positive_public_categories
        ReactionCategory.public.filter { |slug| ReactionCategory[slug].positive? }
      end

      def organization_filter_predicate
        ids = excluded_organization_ids
        return nil if ids.blank?

        article_table = Article.arel_table
        article_table[:organization_id].eq(nil).or(article_table[:organization_id].not_in(ids))
      end

      def excluded_tags_predicate
        ids = excluded_tag_ids
        return nil if ids.blank?

        taggings = ActsAsTaggableOn::Tagging
          .where(taggable_type: "Article", tag_id: ids)
          .where.not(taggable_id: nil)
          .select(:taggable_id)

        Article.arel_table[:id].not_in(taggings)
      rescue NameError
        nil
      end

      def article_score_expression
        "COALESCE(articles.score, 0)"
      end

      def excluded_organization_ids
        @excluded_organization_ids ||= begin
          ids = ::Settings::General.top_articles_digest_excluded_organization_ids
          ids = DEFAULT_EXCLUDED_ORGANIZATION_IDS if ids.nil?

          Array(ids).map do |value|
            value.to_i if value.to_i.positive?
          end.compact.uniq
        rescue NameError
          DEFAULT_EXCLUDED_ORGANIZATION_IDS
        end
      end

      def minimum_score
        @minimum_score ||= begin
          value = ::Settings::General.top_articles_digest_minimum_score
          value = 0 if value.nil?
          value.to_i
        rescue NameError
          0
        end
      end

      def excluded_tag_ids
        @excluded_tag_ids ||= begin
          names = excluded_tags
          return [] if names.blank?

          normalized_names = names.map { |name| name.to_s.strip.downcase }.reject(&:blank?).uniq
          return [] if normalized_names.blank?

          canonical_names = normalized_names.map do |tag|
            Tag.find_preferred_alias_for(tag)
          rescue NameError
            tag
          end

          lookup_names = (normalized_names + canonical_names).compact.map(&:downcase).uniq

          tag_scope = Tag.where(name: lookup_names)
          if Tag.column_names.include?("alias_for")
            tag_scope = tag_scope.or(Tag.where(alias_for: lookup_names))
          end

          tag_scope.distinct.pluck(:id)
        rescue NameError
          []
        end
      end

      def excluded_tags
        raw = ::Settings::General.top_articles_digest_excluded_tags

        Array(raw).flat_map do |value|
          value.to_s.split(/[\n,;]+/)
        end.map { |segment| segment.to_s.strip }.reject(&:blank?).uniq
      rescue NameError
        []
      end
    end
  end
end
