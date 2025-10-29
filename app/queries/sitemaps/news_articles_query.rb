module Sitemaps
  class NewsArticlesQuery
    WINDOW = 48.hours
    LIMIT = 1_000

    def initialize(settings: Settings::General)
      @settings = settings
    end

    def call
      return Article.none if tags.blank? || organization_ids.blank?

      Article.published
             .where(organization_id: organization_ids)
             .where("published_at >= ?", WINDOW.ago)
             .tagged_with(tags, any: true)
             .includes(:organization, :tags)
             .order(published_at: :desc)
             .limit(LIMIT)
             .distinct
    end

    private

    attr_reader :settings

    def tags
      @tags ||= Array(settings.news_sitemap_tags).filter_map do |tag|
        sanitized_tag = tag.to_s.strip
        sanitized_tag.downcase if sanitized_tag.present?
      end.uniq
    end

    def organization_ids
      @organization_ids ||= Array(settings.news_sitemap_organization_ids).filter_map do |value|
        sanitized = value.to_s.strip
        next if sanitized.blank?
        next unless sanitized.match?(/\A\d+\z/)

        sanitized.to_i
      end.uniq
    end
  end
end
