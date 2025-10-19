module Users
  class RecalculateReputation
    VALID_STATUSES = %w[valid confirmed].freeze

    def self.call
      new.call
    end

    def call
      counts = like_counts_by_recipient

      User.transaction do
        User.update_all(reputation_score: 0)

        counts.each do |user_id, score|
          User.where(id: user_id).update_all(reputation_score: score)
        end
      end

      { users: counts.size, likes: counts.values.sum }
    end

    private

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
        .joins("INNER JOIN comments ON comments.id = reactions.reactable_id")
        .where.not(comments: { user_id: nil })
        .group("comments.user_id")
        .count
    end

    def article_like_counts
      Reaction.where(category: "like", status: VALID_STATUSES, reactable_type: "Article")
        .joins("INNER JOIN articles ON articles.id = reactions.reactable_id")
        .where.not(articles: { user_id: nil })
        .group("articles.user_id")
        .count
    end
  end
end
