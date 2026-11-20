module Articles
  module Feeds
    # Fork-only: keeps the default home feed from being a wall of editorial
    # (news) posts. Walks one already-loaded feed page in order and never lets
    # more than `interval - 1` editorial posts run back to back: before the post
    # that would overflow the run it emits a community post, preferring one
    # further down the same page (moved up) and otherwise a supplementary hot
    # community post fetched with a single lazy query.
    #
    # Editorial = organization_id in `editorial_organization_ids`; everything
    # else (no organization or another organization) is a community post.
    #
    # The page is never shortened and no editorial post is dropped or
    # reordered; when no community post is available the editorial post is
    # emitted as is. The page grows by the number of supplements used.
    class CommunityMixer
      LOOKBACK = 14.days

      def self.call(...)
        new(...).call
      end

      # @param articles [Array<Article>, ActiveRecord::Relation] one feed page, in order
      # @param user [User, nil] the viewer; hidden tags and blocked authors are honoured
      # @param page [Integer] feed page, used to offset supplements between pages
      # @param editorial_organization_ids [Array<Integer>]
      # @param interval [Integer, nil] one community post per this many posts at most;
      #   <= 1 disables mixing
      # @param exclude_ids [Array<Integer>] never supplement these (e.g. stories the caller
      #   renders elsewhere on the page); does not change the supplement limit/offset
      def initialize(articles, user:, page:, editorial_organization_ids:, interval:, exclude_ids: [])
        @articles = articles
        @user = user
        @page = [page.to_i, 1].max
        @editorial_organization_ids = Array(editorial_organization_ids)
        @max_editorial_run = interval.to_i - 1
        @exclude_ids = Array(exclude_ids).compact
      end

      def call
        return @articles if @max_editorial_run < 1 || @editorial_organization_ids.empty?

        base = @articles.to_a
        return @articles if base.empty?

        @base_ids = base.map(&:id)
        mix(base)
      end

      private

      def mix(base)
        pending = base.dup
        result = []
        editorial_run = 0

        while (article = pending.shift)
          unless editorial?(article)
            result << article
            editorial_run = 0
            next
          end

          if editorial_run >= @max_editorial_run && (community = take_later_community(pending) || next_supplement)
            result << community
            editorial_run = 0
          end

          result << article
          editorial_run += 1
        end

        result
      end

      def editorial?(article)
        @editorial_organization_ids.include?(article.organization_id)
      end

      # Moves the first community post still waiting further down the page up to here.
      def take_later_community(pending)
        index = pending.index { |article| !editorial?(article) }
        index && pending.delete_at(index)
      end

      def next_supplement
        @supplements ||= supplement_scope.to_a
        @supplements.shift
      end

      # Upper bound on the slots a page of this size can need when it is all
      # editorial; based on the page size (stable per strategy) so the offset
      # walks through distinct supplements page after page.
      def supplement_limit
        (@base_ids.size - 1) / @max_editorial_run
      end

      def supplement_scope
        limit = supplement_limit
        return Article.none if limit < 1

        scope = Article.published
          .with_at_least_home_feed_minimum_score
          .from_subforem
          .where("articles.organization_id IS NULL OR articles.organization_id NOT IN (?)",
                 @editorial_organization_ids)
          .where(score: 0..)
          .where("articles.published_at > ?", LOOKBACK.ago)
          .where.not(id: @base_ids + @exclude_ids)
          .limited_column_select
          .order(hotness_score: :desc)
          .limit(limit)
          .offset((@page - 1) * limit)

        return scope unless @user

        scope = scope.where.not(user_id: UserBlock.cached_blocked_ids_for_blocker(@user.id))
        if (hidden_tags = @user.cached_antifollowed_tag_names).any?
          scope = scope.not_cached_tagged_with_any(hidden_tags)
        end
        scope
      end
    end
  end
end
