module Users
  class CalculateMonthlyReputation
    BADGE_SLUG = "d0-a2-d0-be-d0-bf-10-d0-ba-d0-be-d1-80-d0-b8-d1-81-d1-82-d1-83-d0-b2-d0-b0-d1-87-d1-96-d0-b2-d0-bc-d1-96-d1-81-d1-8f-d1-86-d1-8f".freeze
    VALID_STATUSES = Users::RecalculateReputation::VALID_STATUSES

    def self.call(period: default_period)
      new(period: period).call
    end

    def self.default_period
      Time.zone.today.prev_month.beginning_of_month
    end

    def initialize(period: self.class.default_period)
      @period = period.to_date.beginning_of_month
    end

    def call
      counts = like_counts_by_recipient
      existing_awards = existing_awards_by_user_id

      rows = build_rows(counts, existing_awards)

      MonthlyUserReputation.transaction do
        upsert_rows(rows)
        cleanup_missing_users(counts.keys)
      end

      award_top_ten
    end

    private

    attr_reader :period

    def build_rows(counts, existing_awards)
      timestamp = Time.current

      counts
        .sort_by { |user_id, score| [-score, user_id] }
        .map
        .with_index(1) do |(user_id, score), index|
          {
            user_id: user_id,
            period: period,
            score: score,
            rank: index,
            awarded_top_ten_at: existing_awards[user_id],
            created_at: timestamp,
            updated_at: timestamp,
          }
        end
    end

    def upsert_rows(rows)
      return if rows.empty?

      MonthlyUserReputation.upsert_all(
        rows,
        unique_by: :index_monthly_user_reputations_on_period_and_user_id,
      )
    end

    def cleanup_missing_users(user_ids)
      MonthlyUserReputation.where(period: period)
        .where.not(user_id: user_ids)
        .delete_all
    end

    def existing_awards_by_user_id
      MonthlyUserReputation.for_period(period).pluck(:user_id, :awarded_top_ten_at).to_h
    end

    def award_top_ten
      leaderboard = MonthlyUserReputation.for_period(period).order(:rank).limit(10).includes(:user)
      to_award = leaderboard.reject { |entry| entry.awarded_top_ten_at.present? }
      return if to_award.empty?

      return unless Badge.id_for_slug(BADGE_SLUG)

      message = I18n.t(
        "services.users.calculate_monthly_reputation.badge_message",
        month: formatted_period,
      )

      Badges::Award.call(
        User.where(id: to_award.map(&:user_id)),
        BADGE_SLUG,
        message,
        include_default_description: false,
      )

      MonthlyUserReputation.where(id: to_award.map(&:id)).update_all(awarded_top_ten_at: Time.current)
    end

    def formatted_period
      I18n.l(period, format: :long_month)
    end

    def like_counts_by_recipient
      [comment_like_counts, article_like_counts].each_with_object(Hash.new(0)) do |counts, totals|
        counts.each do |user_id, score|
          next if user_id.nil?

          totals[user_id] += score
        end
      end
    end

    def comment_like_counts
      Reaction.where(category: "like", status: VALID_STATUSES, reactable_type: "Comment")
        .where(created_at: period..period.end_of_month.end_of_day)
        .joins("INNER JOIN comments ON comments.id = reactions.reactable_id")
        .where.not(comments: { user_id: nil })
        .group("comments.user_id")
        .count
    end

    def article_like_counts
      Reaction.where(category: "like", status: VALID_STATUSES, reactable_type: "Article")
        .where(created_at: period..period.end_of_month.end_of_day)
        .joins("INNER JOIN articles ON articles.id = reactions.reactable_id")
        .where.not(articles: { user_id: nil })
        .group("articles.user_id")
        .count
    end
  end
end
