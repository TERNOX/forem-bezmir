# frozen_string_literal: true

module Articles
  module TopArticles
    class DigestPublisher
      SUPPORTED_FREQUENCIES = %w[daily weekly monthly].freeze
      CUSTOM_FREQUENCY = "custom".freeze

      def initialize(reference_time: nil, period_range: nil, limit: nil)
        @reference_time = parse_reference_time(reference_time)
        @period_range_override = normalize_period_range(period_range)
        @limit_override = parse_limit(limit)
      end

      def call(test: false)
        return unless ready_for_publication?
        return if preview_articles.blank?
        return if !test && !publication_due?

        article = Articles::Creator.call(bot_user, article_params)

        if article.persisted? && !test
          Settings::General.set_top_articles_digest_last_period_identifier(current_identifier)
          Settings::General.set_top_articles_digest_last_article_id(article.id)
        end

        article
      end

      def publication_errors
        [].tap do |errors|
          if Settings::General.top_articles_digest_bot_api_key.blank?
            errors << I18n.t("services.articles.top_articles.digest_publisher.errors.missing_api_key")
          elsif api_secret.blank?
            errors << I18n.t("services.articles.top_articles.digest_publisher.errors.invalid_api_key")
          elsif bot_user.blank?
            errors << I18n.t("services.articles.top_articles.digest_publisher.errors.missing_bot_user")
          end

          if title_template.blank?
            errors << I18n.t("services.articles.top_articles.digest_publisher.errors.missing_title_template")
          end

          if preview_articles.blank?
            errors << I18n.t("services.articles.top_articles.digest_publisher.errors.no_articles")
          end
        end
      end

      def preview
        {
          available?: preview_ready?,
          articles: preview_articles,
          period_start: period_start.to_date,
          period_end: display_period_end,
          identifier: current_identifier,
          title: rendered_title,
          intro: intro_markdown.to_s,
          embed_urls: embed_urls,
        }
      end

      private

      attr_reader :reference_time

      def parse_reference_time(time)
        return Time.zone.now if time.blank?

        case time
        when Time
          time.in_time_zone
        else
          Time.zone.parse(time.to_s)
        end
      rescue ArgumentError
        Time.zone.now
      end

      def ready_for_publication?
        publication_requirements_met? && bot_user.present?
      end

      def publication_requirements_met?
        api_secret.present? && preview_ready? && title_template.present?
      end

      def preview_ready?
        limit.positive? && frequency.present?
      end

      def publication_due?
        last_identifier = Settings::General.top_articles_digest_last_period_identifier
        custom_period? || last_identifier != current_identifier
      end

      def preview_articles
        @preview_articles ||= begin
          ids = Articles::TopArticles::PeriodQuery.call(start_time: period_start, end_time: period_end, limit: limit)
          return [] if ids.blank?

          articles = Article.includes(:user).where(id: ids).index_by(&:id)
          ids.filter_map { |id| articles[id] }
        end
      end

      def embed_urls
        preview_articles.map { |article| "{% embed #{app_url(article.path)} %}" }
      end

      def rendered_title
        template = title_template.to_s
        return template if template.blank?

        I18n.with_locale(digest_locale) do
          replacements = {
            "period_start" => I18n.l(period_start.to_date, format: :long),
            "period_end" => I18n.l(display_period_end, format: :long),
            "count" => preview_articles.count,
            "frequency" => frequency,
            "generated_on" => I18n.l(reference_time.to_date, format: :long),
          }

          replacements.reduce(template) do |result, (key, value)|
            result.gsub("{{#{key}}}", value.to_s)
          end
        end
      end

      def article_params
        params = {
          title: rendered_title,
          body_markdown: body_markdown,
          main_image: image_url.presence,
          published: true,
          published_at: reference_time,
          tags: Settings::General.top_articles_digest_tags,
        }

        if organization_id.present?
          params[:organization_id] = organization_id
        end

        params
      end

      def body_markdown
        parts = []
        parts << intro_markdown.to_s.strip if intro_markdown.present?
        parts << embed_urls.join("\n\n") if embed_urls.present?
        parts.compact_blank.join("\n\n")
      end

      def bot_user
        api_secret&.user
      end

      def api_secret
        return @api_secret if defined?(@api_secret)

        api_key = Settings::General.top_articles_digest_bot_api_key
        @api_secret = ApiSecret.includes(:user).find_by(secret: api_key)
      end

      def limit
        @limit ||= begin
          return @limit_override if @limit_override && @limit_override.to_i.positive?

          configured = Settings::General.top_articles_digest_article_limit.to_i
          configured.positive? ? configured : Articles::TopArticles::PeriodQuery::DEFAULT_LIMIT
        end
      end

      def frequency
        return @frequency if defined?(@frequency)

        @frequency = if custom_period?
          CUSTOM_FREQUENCY
        else
          value = Settings::General.top_articles_digest_frequency.to_s.downcase
          value = "weekly" if value.blank?
          SUPPORTED_FREQUENCIES.include?(value) ? value : "weekly"
        end
      end

      def title_template
        Settings::General.top_articles_digest_title_template
      end

      def intro_markdown
        Settings::General.top_articles_digest_intro_markdown
      end

      def image_url
        Settings::General.top_articles_digest_image_url
      end

      def organization_id
        return @organization_id if defined?(@organization_id)

        configured = Settings::General.top_articles_digest_organization_id.to_i
        if configured.positive? && organization_membership?(configured)
          @organization_id = configured
        else
          @organization_id = nil
        end
      end

      def organization_membership?(org_id)
        Organization.exists?(id: org_id) &&
          OrganizationMembership.exists?(user_id: bot_user&.id, organization_id: org_id)
      end

      def period_start
        @period_start ||= period_range.begin
      end

      def period_end
        @period_end ||= period_range.end
      end

      def current_identifier
        @current_identifier ||= begin
          case frequency
          when "daily"
            "daily:#{period_start.to_date.iso8601}"
          when "monthly"
            date = period_start.to_date
            "monthly:#{format('%<year>d-%<month>02d', year: date.year, month: date.month)}"
          when CUSTOM_FREQUENCY
            "custom:#{period_start.to_date.iso8601}-#{display_period_end.iso8601}"
          else
            "weekly:#{period_start.to_date.iso8601}"
          end
        end
      end

      def app_url(path)
        URL.url(path)
      end

      def display_period_end
        (period_end - 1.second).to_date
      end

      def digest_locale
        Settings::General.default_content_language.presence&.to_sym || I18n.default_locale
      end

      def period_range
        return @period_range if defined?(@period_range)

        @period_range = if custom_period?
          @period_range_override
        else
          case frequency
          when "daily"
            start_time = (reference_time - 1.day).beginning_of_day
            start_time...(start_time + 1.day)
          when "monthly"
            start_time = (reference_time - 1.month).beginning_of_month.beginning_of_day
            start_time...(start_time + 1.month)
          else
            start_time = (reference_time - 1.week).beginning_of_week(:monday).beginning_of_day
            start_time...(start_time + 1.week)
          end
        end
      end

      def custom_period?
        @period_range_override.present?
      end

      def normalize_period_range(range)
        return if range.blank?

        if range.is_a?(Range)
          start_time = parse_reference_time(range.begin)
          end_time = parse_reference_time(range.end)
          return if start_time.blank? || end_time.blank? || end_time <= start_time

          start_time...end_time
        elsif range.respond_to?(:[]) && range[:start_time] && range[:end_time]
          start_time = parse_reference_time(range[:start_time])
          end_time = parse_reference_time(range[:end_time])
          return if start_time.blank? || end_time.blank? || end_time <= start_time

          start_time...end_time
        end
      rescue ArgumentError
        nil
      end

      def parse_limit(limit)
        return unless limit

        value = limit.to_i
        value.positive? ? value : nil
      end
    end
  end
end
