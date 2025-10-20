# This is used to populate the following pages:
# => homepage
# => profile page
# => organization page
# => tag index page
# TODO: rename `Homepage::FetchArticles` to something more generic
module Homepage
  class FetchArticles
    DEFAULT_PER_PAGE = 60

    def self.call(
      approved: nil,
      published_at: nil,
      user_id: nil,
      organization_id: nil,
      tags: [],
      hidden_tags: [],
      sort_by: nil,
      sort_direction: nil,
      page: 0,
      per_page: DEFAULT_PER_PAGE,
      excluded_organization_ids: nil
    )
      articles = Homepage::ArticlesQuery.call(
        approved: approved,
        published_at: published_at,
        user_id: user_id,
        organization_id: organization_id,
        tags: tags,
        hidden_tags: hidden_tags,
        sort_by: sort_by,
        sort_direction: sort_direction,
        page: page,
        per_page: per_page,
      )

      articles = filter_excluded_organizations(articles, excluded_organization_ids)

      Homepage::ArticleSerializer.serialized_collection_from(relation: articles)
    end

    def self.filter_excluded_organizations(articles, excluded_organization_ids)
      return articles if excluded_organization_ids.blank?

      articles
        .where(organization_id: nil)
        .or(articles.where.not(organization_id: excluded_organization_ids))
    end
    private_class_method :filter_excluded_organizations
  end
end
