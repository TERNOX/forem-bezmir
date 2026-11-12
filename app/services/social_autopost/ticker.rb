module SocialAutopost
  # One run of the autoposting loop (every few minutes via cron):
  #   1. queue newly qualifying articles;
  #   2. send items forced for now ("post now", the digest right after it is
  #      published) regardless of the schedule;
  #   3. inside a posting window, once the minimum interval since the last
  #      scheduled post has passed, send the next queued article.
  # Every post, forced ones included, starts a new minimum interval.
  class Ticker
    MAX_SKIPS_PER_TICK = 20
    STUCK_AFTER = 15.minutes

    def self.call(...)
      new(...).call
    end

    def initialize(now: Time.current, client: TelegramClient.new, schedule: Schedule.new)
      @now = now
      @client = client
      @schedule = schedule
    end

    def call
      return :disabled unless SocialAutopost.active?

      release_stuck_items
      Enqueuer.enqueue_candidates(now: now)
      return :setup_error if post_forced_items == :setup_error
      return :closed unless schedule.open_at?(now)
      return :waiting if next_post_not_before && next_post_not_before > now
      return :daily_limit if daily_limit_reached?

      post_next_scheduled
    end

    private

    attr_reader :now, :client, :schedule

    # A send interrupted mid-way (process killed) may or may not have reached
    # Telegram, so it is not retried automatically: an admin can requeue it.
    def release_stuck_items
      SocialAutopostItem.where(status: "sending", updated_at: ...(now - STUCK_AFTER))
        .update_all(status: "failed", last_error: "Interrupted while sending; check the channel before requeueing.",
                    updated_at: Time.current)
    end

    def post_forced_items
      SocialAutopostItem.queued.where(post_after: ..now).order(:post_after, :id).each do |item|
        result = Poster.call(item, client: client, now: now)
        return result if result == :setup_error
      end
      nil
    end

    def post_next_scheduled
      MAX_SKIPS_PER_TICK.times do
        item = SocialAutopostItem.ordered_queue.where(post_after: nil).first
        return :empty unless item

        result = Poster.call(item, client: client, now: now)
        case result
        when :posted
          return :posted
        when :skipped, :not_claimed
          next
        else
          return result
        end
      end
      :empty
    end

    def next_post_not_before
      value = Settings::SocialAutopost.next_post_not_before
      value.present? ? Time.zone.parse(value) : nil
    rescue ArgumentError
      nil
    end

    def daily_limit_reached?
      limit = Settings::SocialAutopost.max_posts_per_day.to_i
      return false unless limit.positive?

      day_start = schedule.beginning_of_local_day(now)
      SocialAutopostItem.posted.where(posted_at: day_start..now).count >= limit
    end
  end
end
