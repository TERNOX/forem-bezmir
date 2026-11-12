module Admin
  # Fork-only: Telegram autoposting of community articles — settings, queue
  # and history on one page.
  class SocialAutopostsController < Admin::ApplicationController
    layout "admin"

    BOOLEAN_SETTINGS = %i[
      enabled disable_link_preview include_community_favorites include_staff_posts include_official_posts
      use_digest_filters post_digest
    ].freeze
    INTEGER_SETTINGS = %i[
      minimum_score minimum_reactions max_age_days minimum_body_length minimum_video_body_length
      min_interval_minutes random_delay_minutes max_posts_per_day
    ].freeze
    STRING_SETTINGS = %i[
      telegram_chat_id published_after queue_order digest_timing template_community template_staff template_digest
    ].freeze
    ARRAY_SETTINGS = %i[staff_usernames excluded_tags].freeze
    SCHEDULE_SETTINGS = ::Settings::SocialAutopost::WEEKDAYS.map { |day| :"schedule_#{day}" }.freeze
    UPCOMING_LIMIT = 30

    def index
      @settings = ::Settings::SocialAutopost
      @queue = SocialAutopostItem.ordered_queue.includes(article: %i[user organization]).limit(100).to_a
      @queued_count = SocialAutopostItem.queued.count
      @history = SocialAutopostItem.history.includes(:article).limit(50)
      @organizations = Organization.order(:name).pluck(:name, :id)
      @upcoming_times = upcoming_times
      @digest_settings = {
        minimum_body_length: ::Settings::General.top_articles_digest_minimum_body_length,
        excluded_tags: Array(::Settings::General.top_articles_digest_excluded_tags).join(", ")
      }
    end

    def update_settings
      permitted = params.require(:social_autopost).permit(
        *BOOLEAN_SETTINGS, *INTEGER_SETTINGS, *STRING_SETTINGS, *ARRAY_SETTINGS, *SCHEDULE_SETTINGS,
        :telegram_bot_token, :clear_telegram_bot_token, official_organization_ids: []
      )
      validate_settings!(permitted)
      save_settings(permitted)
      redirect_to admin_social_autoposts_path, flash: { success: "Autoposting settings saved." }
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      redirect_to admin_social_autoposts_path, flash: { danger: e.message }
    end

    def check_bot
      result = SocialAutopost::TelegramClient.new.check
      if result[:can_post]
        flash[:success] = "Bot #{result[:bot]} can post to “#{result[:chat]}”."
      else
        flash[:danger] = "Bot #{result[:bot]} sees “#{result[:chat]}” but is not allowed to post there. " \
                         "Make it a channel admin with the “Post messages” right."
      end
      redirect_to admin_social_autoposts_path
    rescue SocialAutopost::TelegramClient::Error => e
      redirect_to admin_social_autoposts_path, flash: { danger: e.message }
    end

    def refresh_queue
      added = SocialAutopost::Enqueuer.enqueue_candidates
      redirect_to admin_social_autoposts_path, flash: { success: "#{added} new article(s) added to the queue." }
    end

    def add_item
      article = find_article(params[:article].to_s)
      return redirect_to(admin_social_autoposts_path, flash: { danger: "Article not found." }) unless article

      SocialAutopost::Enqueuer.add_manual(article)
      redirect_to admin_social_autoposts_path, flash: { success: "“#{article.title}” is now first in the queue." }
    rescue SocialAutopost::Enqueuer::Error, ActiveRecord::RecordInvalid => e
      redirect_to admin_social_autoposts_path, flash: { danger: e.message }
    end

    protected

    def authorization_resource
      SocialAutopostItem
    end

    private

    def validate_settings!(permitted)
      SCHEDULE_SETTINGS.each { |key| SocialAutopost::Schedule.parse(permitted[key]) if permitted.key?(key) }

      if permitted[:published_after].present?
        Time.zone.parse(permitted[:published_after]) || raise(ArgumentError, "Invalid “published after” date.")
      end

      %i[template_community template_staff template_digest].each do |key|
        next if permitted[key].to_s.length <= SocialAutopost::MessageBuilder::MAX_LENGTH

        raise ArgumentError, "Templates must be at most #{SocialAutopost::MessageBuilder::MAX_LENGTH} characters."
      end
    end

    def save_settings(permitted)
      settings = ::Settings::SocialAutopost

      BOOLEAN_SETTINGS.each { |key| settings.public_send(:"#{key}=", permitted[key]) if permitted.key?(key) }
      INTEGER_SETTINGS.each do |key|
        settings.public_send(:"#{key}=", [permitted[key].to_i, 0].max) if permitted.key?(key)
      end
      (STRING_SETTINGS + SCHEDULE_SETTINGS).each do |key|
        settings.public_send(:"#{key}=", permitted[key].to_s.strip) if permitted.key?(key)
      end
      ARRAY_SETTINGS.each { |key| settings.public_send(:"#{key}=", permitted[key].to_s) if permitted.key?(key) }

      if permitted.key?(:official_organization_ids)
        settings.official_organization_ids = Array(permitted[:official_organization_ids]).compact_blank.join(",")
      end

      if permitted[:clear_telegram_bot_token] == "1"
        settings.telegram_bot_token = ""
      elsif permitted[:telegram_bot_token].present?
        settings.telegram_bot_token = permitted[:telegram_bot_token].strip
      end
    end

    def find_article(value)
      value = value.strip
      return Article.find_by(id: value) if value.match?(/\A\d+\z/)

      if (match = value.match(%r{/s/(\d+)}))
        return Article.find_by(id: match[1])
      end

      path = URI.parse(value).path.to_s.chomp("/")
      Article.find_by(path: path) if path.present?
    rescue URI::InvalidURIError
      nil
    end

    def upcoming_times
      return [] unless SocialAutopost.active?

      schedule = SocialAutopost::Schedule.new
      interval = [::Settings::SocialAutopost.min_interval_minutes.to_i, 1].max.minutes
      not_before = ::Settings::SocialAutopost.next_post_not_before.presence
      time = [Time.current, (not_before && Time.zone.parse(not_before)) || Time.current].max

      @queue.first(UPCOMING_LIMIT).each_with_object({}) do |item, times|
        next if item.post_after.present?

        time = schedule.next_open_at(time)
        break times unless time

        times[item.id] = time
        time += interval
      end
    rescue ArgumentError
      {}
    end
  end
end
