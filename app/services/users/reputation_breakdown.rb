module Users
  class ReputationBreakdown
    VALID_STATUSES = Users::RecalculateReputation::VALID_STATUSES

    def self.call(user)
      new(user).call
    end

    def initialize(user)
      @user = user
    end

    def call
      {
        articles: article_score,
        comments: comment_score,
      }
    end

    private

    attr_reader :user

    def base_scope
      Reaction.where(category: "like", status: VALID_STATUSES)
    end

    def article_score
      @article_score ||= base_scope
        .where(reactable_type: "Article")
        .joins("INNER JOIN articles ON articles.id = reactions.reactable_id")
        .where(articles: { user_id: user.id })
        .count * 2
    end

    def comment_score
      @comment_score ||= base_scope
        .where(reactable_type: "Comment")
        .joins("INNER JOIN comments ON comments.id = reactions.reactable_id")
        .where(comments: { user_id: user.id })
        .count
    end
  end
end
