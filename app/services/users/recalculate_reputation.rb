module Users
  class RecalculateReputation
    VALID_STATUSES = %w[valid confirmed].freeze

    def self.call
      new.call
    end

    def call
      counts = comment_like_counts
      users_updated = 0
      total_likes = 0

      User.transaction do
        User.update_all(reputation_score: 0)

        counts.each do |user_id, score|
          next if user_id.nil?

          User.where(id: user_id).update_all(reputation_score: score)
          users_updated += 1
          total_likes += score
        end
      end

      { users: users_updated, likes: total_likes }
    end

    private

    def comment_like_counts
      Reaction.where(category: "like", status: VALID_STATUSES, reactable_type: "Comment")
        .joins("INNER JOIN comments ON comments.id = reactions.reactable_id")
        .where.not(comments: { user_id: nil })
        .group("comments.user_id")
        .count
    end
  end
end
