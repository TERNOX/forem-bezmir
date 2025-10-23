module TopArticles
  class DigestConfiguration
    FREQUENCY_OPTIONS = %w[daily weekly biweekly monthly].freeze

    Period = Struct.new(:start_time, :end_time, keyword_init: true) do
      def start_date
        start_time.to_date
      end

      def end_date
        (end_time - 1.second).to_date
      end
    end

    attr_reader :bot_api_key, :title_template, :tags, :image_url,
                :organization_id, :intro_paragraph, :frequency,
                :article_count, :badge_slug

    def initialize(bot_api_key: Settings::General.top_articles_digest_bot_api_key,
                   title_template: Settings::General.top_articles_digest_title_template,
                   tags: Settings::General.top_articles_digest_tags,
                   image_url: Settings::General.top_articles_digest_image_url,
                   organization_id: Settings::General.top_articles_digest_organization_id,
                   intro_paragraph: Settings::General.top_articles_digest_intro_paragraph,
                   frequency: Settings::General.top_articles_digest_frequency,
                   article_count: Settings::General.top_articles_digest_article_count,
                   badge_slug: Settings::General.top_articles_digest_badge_slug)
      @bot_api_key = bot_api_key.presence
      @title_template = title_template.presence || default_title_template
      @tags = Array(tags).map(&:to_s)
      @image_url = image_url.presence
      @organization_id = organization_id.presence && organization_id.to_i
      @intro_paragraph = intro_paragraph.to_s
      @frequency = normalize_frequency(frequency)
      @article_count = normalize_article_count(article_count)
      @badge_slug = badge_slug.presence
    end

    def article_limit
      article_count
    end

    def tags_array
      tags.filter_map { |tag| tag.to_s.strip.presence }
    end

    def period_for(reference_time)
      case frequency
      when "daily"
        daily_period(reference_time)
      when "biweekly"
        multiweek_period(reference_time, weeks: 2)
      when "monthly"
        monthly_period(reference_time)
      else
        multiweek_period(reference_time, weeks: 1)
      end
    end

    def title_for(selection, article_count: nil)
      count_value = article_count || selection.article_ids.size
      replacements = {
        "period_label" => selection.period_label,
        "period_start" => I18n.l(selection.period_start.to_date, format: :long),
        "period_end" => I18n.l(selection.period_range.max, format: :long),
        "count" => count_value.to_s,
        "frequency" => frequency,
        "current_date" => I18n.l(Time.zone.today, format: :long),
      }

      replacements.reduce(title_template.dup) do |memo, (token, value)|
        memo.gsub("{{#{token}}}", value)
      end
    end

    private

    def default_title_template
      "Top {{count}} posts from {{period_label}}"
    end

    def normalize_frequency(value)
      value = value.to_s.downcase
      FREQUENCY_OPTIONS.include?(value) ? value : "weekly"
    end

    def normalize_article_count(value)
      count = value.to_i
      count.positive? ? count : 7
    end

    def daily_period(reference_time)
      end_time = reference_time.in_time_zone.beginning_of_day
      Period.new(start_time: end_time - 1.day, end_time: end_time)
    end

    def multiweek_period(reference_time, weeks: 1)
      end_time = reference_time.in_time_zone.beginning_of_week(:monday)
      Period.new(start_time: end_time - weeks.weeks, end_time: end_time)
    end

    def monthly_period(reference_time)
      end_time = reference_time.in_time_zone.beginning_of_month
      Period.new(start_time: (end_time - 1.month).beginning_of_month, end_time: end_time)
    end
  end
end
