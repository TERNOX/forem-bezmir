module Badges
  class AwardWeeklyTopSevenWorker
    include Sidekiq::Job

    sidekiq_options queue: :medium_priority, retry: 10

    def perform(run_time = nil)
      reference_time = run_time ? Time.zone.parse(run_time) : Time.zone.now
      week_start = (reference_time - 1.week).beginning_of_week(:monday).to_date

      selection = TopSevenArticleSelection.ensure_for_week!(week_start) do
        Articles::TopSeven::WeeklyQuery.call(week_start, limit: configured_limit)
      end

      return if selection.article_ids.blank? || selection.awarded_at.present?

      usernames = author_usernames_for(selection)
      return if usernames.blank?

      Badges::AwardTopSeven.call(usernames)
      selection.update!(awarded_at: Time.current)
    end

    private

    def configured_limit
      limit = Settings::General.top_articles_digest_article_limit.to_i
      limit.positive? ? limit : Articles::TopArticles::PeriodQuery::DEFAULT_LIMIT
    end

    def author_usernames_for(selection)
      articles_by_id = Article.where(id: selection.article_ids).includes(:user).index_by(&:id)

      selection.article_ids.each_with_object([]) do |article_id, usernames|
        article = articles_by_id[article_id]
        next unless article&.user

        username = article.user.username
        usernames << username unless usernames.include?(username)
      end
    end
  end
end
