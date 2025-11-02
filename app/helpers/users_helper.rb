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
    breakdown = Users::ReputationBreakdown.call(user)
    total = breakdown.values.sum

    {
      total: total,
      formatted_total: number_with_delimiter(total),
      articles: breakdown_item(breakdown[:articles], total),
      comments: breakdown_item(breakdown[:comments], total),
    }
  end

  private

  def breakdown_item(points, total)
    percentage = total.zero? ? 0 : (points.to_f / total) * 100

    {
      points: points,
      formatted_points: number_with_delimiter(points),
      percentage: percentage,
      formatted_percentage: number_to_percentage(percentage, precision: 0),
    }
  end
end
