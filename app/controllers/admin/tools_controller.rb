module Admin
  class ToolsController < Admin::ApplicationController
    layout "admin"

    def index
      @top_seven_selections = TopSevenArticleSelection.ordered
      article_ids = @top_seven_selections.flat_map(&:article_ids)
      @top_seven_articles_by_id = Article.where(id: article_ids).includes(:user).index_by(&:id)
      @digest_preview_mode = digest_preview_mode
      @digest_preview_form_params = digest_preview_form_params.to_h.symbolize_keys
      @digest_period_range = digest_period_range
      @top_articles_digest_preview = build_digest_publisher.preview
      @top_articles_digest_settings = current_digest_settings
      @top_articles_digest_status = top_articles_digest_status
      @top_articles_digest_next_run_at = top_articles_digest_next_run_at
      @monthly_top_users_settings = monthly_top_users_settings
      @monthly_top_users_status = monthly_top_users_status
      @monthly_top_users_next_run_at = monthly_top_users_schedule.next_run_at
    rescue InvalidDigestPreviewRangeError => e
      flash.now[:danger] = e.message
      @top_articles_digest_preview = { available?: false, articles: [], embed_urls: [] }
      @top_articles_digest_settings = current_digest_settings
      @top_articles_digest_status = top_articles_digest_status
      @top_articles_digest_next_run_at = top_articles_digest_next_run_at
      @monthly_top_users_settings = monthly_top_users_settings
      @monthly_top_users_status = monthly_top_users_status
      @monthly_top_users_next_run_at = monthly_top_users_schedule.next_run_at
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

    def resave_published_articles
      Articles::ResavePublishedWorker.perform_async
      flash[:success] = I18n.t("admin.tools_controller.resave_published_articles.enqueued")
    rescue StandardError => e
      flash[:danger] = e.message
    ensure
      redirect_to admin_tools_path
    end

    def update_monthly_top_users_awards
      permitted = monthly_top_users_awards_params

      validate_award_day!(permitted[:award_day])

      ::Settings::General.set_monthly_top_users_badge_slug(permitted[:badge_slug])
      ::Settings::General.set_monthly_top_users_award_day(permitted[:award_day])
      ::Settings::General.set_monthly_top_users_award_time(normalized_time(permitted[:award_time]))
      ::Settings::General.set_monthly_top_users_message_template(permitted[:message_template])

      flash[:success] = I18n.t("views.admin.tools.monthly_top_users.save_success")
    rescue StandardError => e
      flash[:danger] = e.message
    ensure
      redirect_to admin_tools_path
    end

    def publish_top_articles_digest_test
      publisher = build_digest_publisher
      errors = publisher.publication_errors

      if errors.present?
        flash[:danger] = errors.first
      else
        article = publisher.call(test: true)

        if article&.persisted?
          flash[:success] = I18n.t(
            "views.admin.tools.top_articles_digest.test_publish.success",
            path: article.path,
          ).html_safe
        else
          message = article&.errors&.full_messages&.to_sentence
          flash[:danger] = message.presence || I18n.t("views.admin.tools.top_articles_digest.test_publish.failure")
        end
      end
    rescue InvalidDigestPreviewRangeError => e
      flash[:danger] = e.message
    rescue StandardError => e
      flash[:danger] = e.message
    ensure
      redirect_to admin_tools_path(digest_preview_redirect_params)
    end

    def award_top_articles_digest_badges
      preview = build_digest_publisher.preview

      if preview[:articles].blank?
        flash[:danger] = I18n.t("views.admin.tools.top_articles_digest.test_badges.missing_articles")
      else
        usernames = preview[:articles].filter_map { |article| article.user&.username }.uniq

        if usernames.blank?
          flash[:danger] = I18n.t("views.admin.tools.top_articles_digest.test_badges.missing_authors")
        else
          Badges::AwardTopSeven.call(usernames)
          flash[:success] = I18n.t(
            "views.admin.tools.top_articles_digest.test_badges.success",
            count: usernames.size,
          )
        end
      end
    rescue InvalidDigestPreviewRangeError => e
      flash[:danger] = e.message
    rescue StandardError => e
      flash[:danger] = e.message
    ensure
      redirect_to admin_tools_path(digest_preview_redirect_params)
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
        publish_time: localized_digest_time(::Settings::General.top_articles_digest_publish_time),
        badge_time: localized_digest_time(::Settings::General.top_articles_digest_badge_time),
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
      ::Settings::General.set_top_articles_digest_publish_time(normalized_digest_time(permitted[:publish_time]))
      ::Settings::General.set_top_articles_digest_badge_time(normalized_digest_time(permitted[:badge_time]))
      ::Settings::General.set_top_articles_badge_slug(permitted[:badge_slug])
      ::Settings::General.set_top_articles_digest_excluded_organization_ids(
        parse_id_list(permitted[:excluded_organization_ids])
      )

      refresh_digest_schedule!
    end

    def build_digest_publisher
      Articles::TopArticles::DigestPublisher.new(
        reference_time: digest_reference_time,
        period_range: digest_period_range,
      )
    end

    def digest_preview_mode
      value = params[:digest_preview_mode].to_s
      value == "custom" ? "custom" : "settings"
    end

    def digest_preview_form_params
      params.fetch(:digest_preview, {}).permit(:start_date, :end_date)
    end

    def digest_preview_redirect_params
      if digest_preview_mode == "custom"
        {
          digest_preview_mode: "custom",
          digest_preview: {
            start_date: digest_preview_form_params[:start_date],
            end_date: digest_preview_form_params[:end_date],
          },
        }
      else
        { digest_preview_mode: "settings" }
      end
    end

    def digest_period_range
      return @digest_period_range if defined?(@digest_period_range)

      if digest_preview_mode == "custom"
        start_value = digest_preview_form_params[:start_date]
        end_value = digest_preview_form_params[:end_date]

        if start_value.blank? || end_value.blank?
          raise InvalidDigestPreviewRangeError, I18n.t("views.admin.tools.top_articles_digest.preview.missing_range")
        end

        begin
          start_date = Date.parse(start_value)
          end_date = Date.parse(end_value)
        rescue ArgumentError
          raise InvalidDigestPreviewRangeError, I18n.t("views.admin.tools.top_articles_digest.preview.invalid_range")
        end

        if end_date < start_date
          raise InvalidDigestPreviewRangeError, I18n.t("views.admin.tools.top_articles_digest.preview.invalid_range")
        end

        start_time = Time.zone.local(start_date.year, start_date.month, start_date.day).beginning_of_day
        end_time = Time.zone.local(end_date.year, end_date.month, end_date.day).next_day.beginning_of_day

        @digest_period_range = start_time...end_time
      else
        @digest_period_range = nil
      end
    end

    def digest_reference_time
      if digest_period_range
        digest_period_range.end - 1.second
      end
    end

    class InvalidDigestPreviewRangeError < StandardError; end

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
        :publish_time,
        :badge_time,
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

    def normalized_digest_time(value)
      hours, minutes = TimeOfDaySetting.extract_components(value)
      return "00:00" if hours.nil? || minutes.nil?

      reference = current_digest_reference_date
      Time.zone.local(reference.year, reference.month, reference.day, hours, minutes).utc.strftime("%H:%M")
    rescue ArgumentError
      "00:00"
    end

    def localized_digest_time(value)
      hours, minutes = TimeOfDaySetting.extract_components(value)
      return format("%02d:%02d", 0, 0) if hours.nil? || minutes.nil?

      reference = current_digest_reference_date
      Time.utc(reference.year, reference.month, reference.day, hours, minutes).in_time_zone.strftime("%H:%M")
    end

    def current_digest_reference_date
      Time.zone.today
    end

    def top_articles_digest_status
      {
        status: ::Settings::General.top_articles_digest_last_run_status,
        at: ::Settings::General.top_articles_digest_last_run_at,
        message: ::Settings::General.top_articles_digest_last_run_message,
      }
    end

    def top_articles_digest_next_run_at
      ::Settings::General.top_articles_digest_next_run_at ||
        Articles::TopArticles::DigestSchedule.new.next_run_at
    end

    def refresh_digest_schedule!
      next_run = Articles::TopArticles::DigestSchedule.new.next_run_at
      ::Settings::General.set_top_articles_digest_next_run_at(next_run)
    end

    def monthly_top_users_awards_params
      params.require(:monthly_top_users).permit(:badge_slug, :award_day, :award_time, :message_template)
    end

    def validate_award_day!(value)
      return if value.to_i.between?(1, 31)

      raise ArgumentError, I18n.t("views.admin.tools.monthly_top_users.errors.invalid_day")
    end

    def monthly_top_users_settings
      {
        badge_slug: ::Settings::General.monthly_top_users_badge_slug,
        award_day: ::Settings::General.monthly_top_users_award_day,
        award_time: ::Settings::General.monthly_top_users_award_time,
        message_template: ::Settings::General.monthly_top_users_message_template,
      }
    end

    def monthly_top_users_status
      period_identifier = ::Settings::General.monthly_top_users_last_awarded_period
      return {} if period_identifier.blank?

      period = Date.strptime(period_identifier, "%Y-%m")

      {
        period: MonthlyUserReputationFormatter.period_label(period),
        at: ::Settings::General.monthly_top_users_last_awarded_at,
        message: ::Settings::General.monthly_top_users_last_awarded_message,
        usernames: ::Settings::General.monthly_top_users_last_awarded_usernames,
      }
    rescue ArgumentError
      {}
    end

    def monthly_top_users_schedule
      @monthly_top_users_schedule ||= Users::MonthlyTopUsersSchedule.new
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
