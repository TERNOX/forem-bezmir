module Admin
  class ToolsController < Admin::ApplicationController
    layout "admin"

    def index
      @top_seven_selections = TopSevenArticleSelection.ordered
      article_ids = @top_seven_selections.flat_map(&:article_ids)
      @top_seven_articles_by_id = Article.where(id: article_ids).includes(:user).index_by(&:id)
      @top_articles_digest_preview = Articles::TopArticles::DigestPublisher.new.preview
      @top_articles_digest_settings = current_digest_settings
    end

    def create
      if params[:top_articles_digest]
        update_top_articles_digest!
        flash[:success] = I18n.t("admin.tools_controller.top_articles_digest_updated")
      else
        flash[:danger] = I18n.t("admin.tools_controller.top_articles_digest_missing")
      end
    rescue StandardError => e
      flash[:danger] = e.message
    ensure
      redirect_to admin_tools_path
    end

    def bust_cache
      flash[:success] =
        if params[:dead_link]
          handle_dead_path
          I18n.t("admin.tools_controller.link_busted", link: params[:dead_link])
        elsif params[:bust_user]
          handle_user_cache
          I18n.t("admin.tools_controller.user_busted", user: params[:bust_user])
        elsif params[:bust_article]
          handle_article_cache
          I18n.t("admin.tools_controller.article_busted", article: params[:bust_article])
        end
      redirect_to admin_tools_path
    rescue StandardError => e
      flash[:danger] = e.message
      redirect_to admin_tools_path
    end

    def feed_playground
      return if params[:config].blank?

      begin
        config_json = JSON.parse(params[:config])
        config = Articles::Feeds::VariantAssembler
          .build_with(catalog: Articles::Feeds.lever_catalog, config: config_json, variant: "test")
        @user = User.find_by(username: params[:username]) || current_user
        @feed = Articles::Feeds::VariantQuery.new(
          config: config,
          user: @user,
          number_of_articles: params[:number_of_articles] || 25,
          page: 1,
          tag: nil,
        )
        @articles = @feed.more_comments_minimal_weight_randomized.to_a
      rescue KeyError, JSON::ParserError, ActiveRecord::StatementInvalid => e
        flash[:danger] = e.message
      end
    end

    def recalculate_reputation
      result = Users::RecalculateReputation.call
      flash[:success] = I18n.t(
        "views.admin.tools.reputation.success",
        users: result[:users],
        likes: result[:likes],
      )
    rescue StandardError => e
      flash[:danger] = e.message
    ensure
      redirect_to admin_tools_path
    end

    private

    def current_digest_settings
      {
        bot_api_key: ::Settings::General.top_articles_digest_bot_api_key,
        title_template: ::Settings::General.top_articles_digest_title_template,
        tags: ::Settings::General.top_articles_digest_tags.join(", "),
        image_url: ::Settings::General.top_articles_digest_image_url,
        organization_id: ::Settings::General.top_articles_digest_organization_id,
        intro_markdown: ::Settings::General.top_articles_digest_intro_markdown,
        frequency: ::Settings::General.top_articles_digest_frequency,
        article_limit: ::Settings::General.top_articles_digest_article_limit,
        badge_slug: ::Settings::General.top_articles_badge_slug,
        excluded_organization_ids: Array(::Settings::General.top_articles_digest_excluded_organization_ids).join(", "),
      }
    end

    def update_top_articles_digest!
      permitted = top_articles_digest_params

      ::Settings::General.set_top_articles_digest_bot_api_key(permitted[:bot_api_key])
      ::Settings::General.set_top_articles_digest_title_template(permitted[:title_template])
      ::Settings::General.set_top_articles_digest_tags(permitted[:tags])
      ::Settings::General.set_top_articles_digest_image_url(permitted[:image_url])
      ::Settings::General.set_top_articles_digest_organization_id(permitted[:organization_id].presence)
      ::Settings::General.set_top_articles_digest_intro_markdown(permitted[:intro_markdown])
      ::Settings::General.set_top_articles_digest_frequency(permitted[:frequency])
      ::Settings::General.set_top_articles_digest_article_limit(permitted[:article_limit].presence)
      ::Settings::General.set_top_articles_badge_slug(permitted[:badge_slug])
      ::Settings::General.set_top_articles_digest_excluded_organization_ids(
        parse_id_list(permitted[:excluded_organization_ids])
      )
    end

    def top_articles_digest_params
      params.require(:top_articles_digest).permit(
        :bot_api_key,
        :title_template,
        :tags,
        :image_url,
        :organization_id,
        :intro_markdown,
        :frequency,
        :article_limit,
        :badge_slug,
        :excluded_organization_ids,
      )
    end

    def parse_id_list(raw_value)
      return [] if raw_value.blank?

      raw_value
        .split(/[\s,]+/)
        .filter_map do |segment|
          next if segment.blank?

          id = segment.to_i
          id if id.positive?
        end
        .uniq
    end

    def handle_dead_path
      bust_link(params[:dead_link])
    end

    def handle_user_cache
      user = User.find(params[:bust_user].to_i)
      user.touch(:profile_updated_at, :last_followed_at, :last_comment_at)
      bust_link(user.path)
    end

    def handle_article_cache
      article = Article.find(params[:bust_article].to_i)
      article.touch(:last_comment_at)
      EdgeCache::BustArticle.call(article)
    end

    def bust_link(link)
      if link.starts_with?(URL.url)
        link.sub!(URL.url, "")
      end

      paths = [
        link,
        "#{link}/",
        "#{link}?i=i",
        "#{link}/?i=i",
      ]

      EdgeCache::Bust.call(paths)
    end
  end
end
