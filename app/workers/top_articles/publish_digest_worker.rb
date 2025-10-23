module TopArticles
  class PublishDigestWorker
    include Sidekiq::Job

    sidekiq_options queue: :medium_priority, retry: 5

    def perform(selection_id)
      selection = TopSevenArticleSelection.find_by(id: selection_id)
      return unless selection
      return if selection.article_ids.blank? || selection.digest_article_id.present?

      config = DigestConfiguration.new
      bot_user = bot_for(config.bot_api_key)
      return unless bot_user

      articles = ordered_articles(selection.article_ids)
      return if articles.blank?

      article = Articles::Creator.call(bot_user, build_params(selection, config, articles, bot_user))
      return unless article.persisted?

      selection.update!(digest_article_id: article.id)
    end

    private

    def bot_for(api_key)
      return if api_key.blank?

      ApiSecret.includes(:user).find_by(secret: api_key)&.user
    end

    def ordered_articles(ids)
      articles = Article.where(id: ids).includes(:user)
      articles_by_id = articles.index_by(&:id)
      ids.filter_map { |id| articles_by_id[id] }
    end

    def build_params(selection, config, articles, bot_user)
      {
        title: title_for(selection, config, articles),
        body_markdown: body_for(config, articles),
        tags: config.tags_array,
        main_image: config.image_url,
        organization_id: organization_for(bot_user, config.organization_id),
        published: true,
      }.compact
    end

    def title_for(selection, config, articles)
      title = config.title_for(selection, article_count: articles.size)
      title.presence || "Top #{articles.size} posts"
    end

    def body_for(config, articles)
      segments = []
      if config.intro_paragraph.present?
        segments << config.intro_paragraph.strip
      end

      segments += articles.map do |article|
        "{% embed #{URL.article(article)} %}"
      end

      segments.join("\n\n") + "\n"
    end

    def organization_for(bot_user, desired_id)
      return unless desired_id.present?

      if bot_user.organization_memberships.exists?(organization_id: desired_id)
        desired_id
      end
    end
  end
end
