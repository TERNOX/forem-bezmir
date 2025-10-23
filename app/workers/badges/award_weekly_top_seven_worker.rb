module Badges
  class AwardWeeklyTopSevenWorker
    include Sidekiq::Job

    sidekiq_options queue: :medium_priority, retry: 10

    def perform(run_time = nil)
      reference_time = run_time ? Time.zone.parse(run_time) : Time.zone.now
      config = TopArticles::DigestConfiguration.new

      period = config.period_for(reference_time)

      return unless should_run_now?(config, reference_time, period)

      selection = TopSevenArticleSelection.ensure_for_period!(
        frequency: config.frequency,
        period_start: period.start_date,
        badge_slug: config.badge_slug,
      ) do
        Articles::TopArticles::ReactionLeaderboard.call(
          start_time: period.start_time,
          end_time: period.end_time,
          limit: config.article_limit,
        )
      end

      return if selection.article_ids.blank?

      if config.badge_slug.present? && selection.awarded_at.blank?
        usernames = author_usernames_for(selection)
        if usernames.present?
          Badges::AwardTopSeven.call(usernames, badge_slug: config.badge_slug)
          selection.update!(awarded_at: Time.current)
        end
      end

      enqueue_digest_publication(selection)
    end

    private

    def author_usernames_for(selection)
      articles_by_id = Article.where(id: selection.article_ids).includes(:user).index_by(&:id)

      selection.article_ids.each_with_object([]) do |article_id, usernames|
        article = articles_by_id[article_id]
        next unless article&.user

        username = article.user.username
        usernames << username unless usernames.include?(username)
      end
    end

    def should_run_now?(config, reference_time, period)
      case config.frequency
      when "daily"
        true
      when "weekly"
        reference_time.monday?
      when "biweekly"
        reference_time.monday? && period_due?(config.frequency, period.start_date, 2.weeks)
      when "monthly"
        reference_time.day == 1
      else
        false
      end
    end

    def period_due?(frequency, period_start, duration)
      last_selection = TopSevenArticleSelection.for_frequency(frequency).ordered.first
      return true unless last_selection

      period_start >= (last_selection.period_start + duration)
    end

    def enqueue_digest_publication(selection)
      return if selection.digest_article_id.present?

      TopArticles::PublishDigestWorker.perform_async(selection.id)
    end
  end
end
