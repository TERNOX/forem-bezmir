module Users
  class RecalculateReputation
    VALID_STATUSES = %w[valid confirmed].freeze

    def self.call
      new.call
    end

    def call
      user_counts = like_counts_by_recipient
      organization_counts = organization_like_counts

      ActiveRecord::Base.transaction do
        User.update_all(reputation_score: 0)
        Organization.update_all(reputation_score: 0)

        user_counts.each do |user_id, score|
          User.where(id: user_id).update_all(reputation_score: score)
        end

        organization_counts.each do |organization_id, score|
          Organization.where(id: organization_id).update_all(reputation_score: score)
        end
      end

      {
        users: user_counts.size,
        likes: user_counts.values.sum,
        organizations: organization_counts.size,
        organization_likes: organization_counts.values.sum,
      }
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

    def organization_like_counts
      Reaction.where(category: "like", status: VALID_STATUSES, reactable_type: "Article")
        .joins("INNER JOIN articles ON articles.id = reactions.reactable_id")
        .where.not(articles: { organization_id: nil })
        .group("articles.organization_id")
        .count
    end
  end
end
