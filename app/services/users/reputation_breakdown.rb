module Users
  class ReputationBreakdown
    VALID_STATUSES = Users::RecalculateReputation::VALID_STATUSES
    ARTICLE_WEIGHT = 2
    COMMENT_WEIGHT = 1

    def self.call(user, range: nil)
      new(user, range: range).call
    end

    def initialize(user, range: nil)
      @user = user
      @range = range
    end

    def call
      {
        articles: article_score,
        comments: comment_score,
      }
    end

    private

    attr_reader :user, :range

    def base_scope
      scope = Reaction.where(category: "like", status: VALID_STATUSES)
      return scope unless range

      scope.where(created_at: range)
    end

    def article_score
      @article_score ||= base_scope
        .where(reactable_type: "Article")
        .joins("INNER JOIN articles ON articles.id = reactions.reactable_id")
        .where(articles: { user_id: user.id })
        .count * ARTICLE_WEIGHT
    end

    def comment_score
      @comment_score ||= base_scope
        .where(reactable_type: "Comment")
        .joins("INNER JOIN comments ON comments.id = reactions.reactable_id")
        .where(comments: { user_id: user.id })
        .count * COMMENT_WEIGHT
    end
  end
end
