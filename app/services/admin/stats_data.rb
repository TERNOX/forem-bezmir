module Admin
  class StatsData
    def initialize(period = 7, time_range: nil, **options)
      @period = options.fetch(:period, period)
      @time_range = time_range
    end

    def call
      time_range = @time_range || @period.days.ago.beginning_of_day..Time.current
      period = if @time_range
                 (time_range.end.to_date - time_range.begin.to_date).to_i + 1
               else
                 @period
               end

      {
        published_posts: Article.where(published_at: time_range).count,
        comments: Comment.where(created_at: time_range).count,
        public_reactions: Reaction.public_category.where(created_at: time_range).count,
        new_users: User.where(registered_at: time_range).count,
        period: period
      }
    end
  end
end
