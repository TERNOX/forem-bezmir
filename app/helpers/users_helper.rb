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

  def reputation_breakdown_tooltip(user)
    breakdown = Users::ReputationBreakdown.call(user)
    total = breakdown.values.sum

    return t("views.users.reputation.tooltip.no_reputation") if total.zero?

    article_percentage = number_to_percentage((breakdown[:articles].to_f / total) * 100, precision: 0)
    comment_percentage = number_to_percentage((breakdown[:comments].to_f / total) * 100, precision: 0)

    t(
      "views.users.reputation.tooltip.breakdown",
      article_percentage: article_percentage,
      article_points: number_with_delimiter(breakdown[:articles]),
      comment_percentage: comment_percentage,
      comment_points: number_with_delimiter(breakdown[:comments]),
    )
  end
end
