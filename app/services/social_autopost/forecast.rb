module SocialAutopost
  # Estimated posting times for the admin queue. Walks the upcoming slots the
  # way the Ticker would: posting windows, minimum gap, daily limit and the
  # one-post-per-author-per-day and author rotation rules.
  class Forecast
    def self.call(...)
      new(...).call
    end

    # @param items [Array<SocialAutopostItem>] queued items in queue order
    # @return [Hash{Integer => ActiveSupport::TimeWithZone}] item id => time
    def initialize(items, limit:, now: Time.current, schedule: Schedule.new)
      @remaining = items.reject { |item| item.post_after.present? }
      @position = @remaining.each_with_index.to_h { |item, index| [item.id, index] }
      @limit = limit
      @now = now
      @schedule = schedule
      @authors_by_day = Hash.new { |hash, day| hash[day] = [] }
      @count_by_day = Hash.new(0)
    end

    def call
      return {} unless SocialAutopost.active?

      seed_today
      time = start_time
      times = {}

      (limit * 4).times do
        break if remaining.empty? || times.size >= limit

        time = schedule.next_open_at(time)
        break unless time

        day = schedule.beginning_of_local_day(time)
        item = next_item_for(day)
        unless item
          time = day + 1.day
          next
        end

        times[item.id] = time
        remaining.delete(item)
        authors_by_day[day] << item.article.user_id
        last_posted[item.article.user_id] = time
        count_by_day[day] += 1
        time += interval
      end
      times
    rescue ArgumentError
      {}
    end

    private

    attr_reader :remaining, :position, :limit, :now, :schedule, :authors_by_day, :count_by_day, :last_posted

    def rotate?
      Settings::SocialAutopost.rotate_authors
    end

    def seed_today
      @last_posted = rotate? ? SocialAutopost.last_posted_at_by_author : {}
      today = schedule.beginning_of_local_day(now)
      authors_by_day[today] = SocialAutopost.posted_author_ids(today..now)
      count_by_day[today] = SocialAutopostItem.posted.where(posted_at: today..now).count
    end

    def start_time
      not_before = Settings::SocialAutopost.next_post_not_before.presence
      [now, (not_before && Time.zone.parse(not_before)) || now].max
    end

    def interval
      [Settings::SocialAutopost.min_interval_minutes.to_i, 1].max.minutes
    end

    def next_item_for(day)
      daily_limit = Settings::SocialAutopost.max_posts_per_day.to_i
      return if daily_limit.positive? && count_by_day[day] >= daily_limit

      eligible = remaining.reject { |item| SocialAutopost.author_waits?(item, authors_by_day[day]) }
      return eligible.first unless rotate?

      # Same order as SocialAutopostItem.ordered_queue, with the authors'
      # turns updated by the posts forecast so far.
      eligible.min_by do |item|
        [-item.priority, last_posted[item.article.user_id]&.to_f || -Float::INFINITY, position[item.id]]
      end
    end
  end
end
