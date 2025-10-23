module Admin
  class ToolsController < Admin::ApplicationController
    layout "admin"

    def index
      @top_seven_selections = TopSevenArticleSelection.ordered
      article_ids = @top_seven_selections.flat_map(&:article_ids)
      @top_seven_articles_by_id = Article.where(id: article_ids).includes(:user).index_by(&:id)
      @digest_configuration = TopArticles::DigestConfiguration.new
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

    def update_top_articles_digest
      settings = digest_settings_params

      Settings::General.set_top_articles_digest_bot_api_key(settings[:bot_api_key])
      Settings::General.set_top_articles_digest_title_template(settings[:title_template])
      Settings::General.set_top_articles_digest_tags(parse_tags(settings[:tags]))
      Settings::General.set_top_articles_digest_image_url(settings[:image_url])
      Settings::General.set_top_articles_digest_organization_id(settings[:organization_id].presence)
      Settings::General.set_top_articles_digest_intro_paragraph(settings[:intro_paragraph])
      Settings::General.set_top_articles_digest_frequency(settings[:frequency])
      Settings::General.set_top_articles_digest_article_count(settings[:article_count])
      Settings::General.set_top_articles_digest_badge_slug(settings[:badge_slug])

      flash[:success] = I18n.t("views.admin.tools.top_articles_digest.updated")
    rescue StandardError => e
      flash[:danger] = e.message
    ensure
      redirect_to admin_tools_path(anchor: "top-articles-digest")
    end

    private

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

    def digest_settings_params
      params.require(:top_articles_digest).permit(
        :bot_api_key,
        :title_template,
        :tags,
        :image_url,
        :organization_id,
        :intro_paragraph,
        :frequency,
        :article_count,
        :badge_slug,
      )
    end

    def parse_tags(tags_string)
      Array(tags_string.to_s.split(/[,\n;]/)).map(&:strip).reject(&:blank?)
    end
  end
end
