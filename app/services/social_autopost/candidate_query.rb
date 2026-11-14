module SocialAutopost
  # Articles that qualify for automatic posting right now and are not in the
  # queue/history yet. Thresholds come from Settings::SocialAutopost; with
  # `use_digest_filters` the minimum length and excluded tags follow the
  # "posts of the week" digest settings. Featured articles bypass the rating
  # and quality filters, but not the age, organization and staff rules.
  class CandidateQuery
    def self.call(...)
      new(...).call
    end

    def initialize(settings: Settings::SocialAutopost, now: Time.current)
      @settings = settings
      @now = now
    end

    def call
      base = Article.published
        .where.not(type_of: Article.type_ofs[:status])
        .where(published_at: oldest_published_at..now)
        .where.not(id: SocialAutopostItem.select(:article_id))
      base = base.where(organization_predicate) if organization_predicate
      base = base.where.not(user_id: staff_user_ids) unless settings.include_staff_posts

      quality = base
        .where("length(coalesce(articles.body_markdown, '')) >= ?", minimum_body_length)
        .where("articles.video IS NULL OR articles.video = '' OR " \
               "length(coalesce(articles.body_markdown, '')) >= ?", minimum_video_body_length)
        .where(rating_predicate)
      quality = quality.where.not(id: excluded_tag_article_ids) if excluded_tag_ids.any?

      # Featured ("Рекомендувати" in the moderation panel) is a deliberate pick
      # by an admin or moderator, so it skips the rating and quality filters.
      scope = settings.include_featured ? quality.or(base.where(featured: true)) : quality

      scope.includes(:user).reject { |article| SocialAutopost.unpostable_author?(article.user) }
    end

    def oldest_published_at
      floor = now - [settings.max_age_days.to_i, 1].max.days
      published_after = parse_time(settings.published_after)
      published_after && published_after > floor ? published_after : floor
    end

    private

    attr_reader :settings, :now

    def rating_predicate
      table = Article.arel_table
      rating = table[:score].gteq(settings.minimum_score.to_i)
      if settings.minimum_reactions.to_i.positive?
        rating = rating.and(table[:public_reactions_count].gteq(settings.minimum_reactions.to_i))
      end
      return rating unless settings.include_community_favorites

      rating.or(table[:favorited_by_user_id].not_eq(nil))
    end

    def organization_predicate
      return if settings.include_official_posts

      ids = SocialAutopost.official_organization_ids
      return if ids.empty?

      table = Article.arel_table
      table[:organization_id].eq(nil).or(table[:organization_id].not_in(ids))
    end

    def staff_user_ids
      SocialAutopost.staff_user_ids
    end

    def minimum_body_length
      if settings.use_digest_filters
        Settings::General.top_articles_digest_minimum_body_length.to_i
      else
        settings.minimum_body_length.to_i
      end
    end

    def minimum_video_body_length
      [settings.minimum_video_body_length.to_i, minimum_body_length].max
    end

    def excluded_tag_names
      raw = settings.use_digest_filters ? Settings::General.top_articles_digest_excluded_tags : settings.excluded_tags
      Array(raw).flat_map { |value| value.to_s.split(/[\n,;]+/) }.map { |name| name.strip.downcase.delete_prefix("#") }
        .compact_blank.uniq
    end

    def excluded_tag_ids
      @excluded_tag_ids ||= begin
        names = excluded_tag_names
        names.empty? ? [] : Tag.where(name: names).or(Tag.where(alias_for: names)).ids
      end
    end

    def excluded_tag_article_ids
      ActsAsTaggableOn::Tagging.where(taggable_type: "Article", tag_id: excluded_tag_ids).select(:taggable_id)
    end

    def parse_time(value)
      return if value.blank?

      Time.zone.parse(value.to_s)
    rescue ArgumentError
      nil
    end
  end
end
