module UsersHelper
  USER_COMMENTS_PARTIAL = "users/comments_section".freeze
  COMMENTS_LOCKED_PARTIAL = "users/comments_locked_cta".freeze

  def user_comments_section
    if user_signed_in?
      USER_COMMENTS_PARTIAL
    else
      COMMENTS_LOCKED_PARTIAL
    end
  end

  def reputation_breakdown(user)
    overall_raw = Users::ReputationBreakdown.call(user)
    monthly_period = Time.zone.today.beginning_of_month.to_date
    monthly_range = monthly_period.beginning_of_day..monthly_period.end_of_month.end_of_day
    monthly_raw = Users::ReputationBreakdown.call(user, range: monthly_range)

    {
      overall: formatted_breakdown(overall_raw).merge(rank: overall_rank_for(user)),
      monthly: formatted_breakdown(monthly_raw).merge(
        period_label: MonthlyUserReputationFormatter.period_label(monthly_period),
        period_param: monthly_period.strftime("%Y-%m"),
        rank: monthly_rank_for(user, monthly_period),
      ),
      points_per_article_like: Users::ReputationBreakdown::ARTICLE_WEIGHT,
      points_per_comment_like: Users::ReputationBreakdown::COMMENT_WEIGHT,
    }
  end

  private

  def formatted_breakdown(breakdown)
    total = breakdown.values.sum

    {
      total: total,
      formatted_total: number_with_delimiter(total),
      articles: breakdown_item(breakdown[:articles], total),
      comments: breakdown_item(breakdown[:comments], total),
    }
  end

  def breakdown_item(points, total)
    percentage = total.zero? ? 0 : (points.to_f / total) * 100

    {
      points: points,
      formatted_points: number_with_delimiter(points),
      percentage: percentage,
      formatted_percentage: number_to_percentage(percentage, precision: 0),
    }
  end

  def overall_rank_for(user)
    return unless user.registered?
    return unless user.member?
    return if user.reputation_score.to_i <= 0

    User.registered
      .member
      .where("reputation_score > ?", user.reputation_score)
      .count
      .succ
  end

  def monthly_rank_for(user, period)
    snapshot = MonthlyUserReputation.for_period(period).find_by(user_id: user.id)
    snapshot&.rank
  end
end
