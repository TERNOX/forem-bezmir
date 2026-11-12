module SocialAutopost
  # Sends one queued item to Telegram. Re-checks the article first, since it
  # may have been unpublished, aged out or had its author banned while queued.
  #
  # @return [Symbol] :posted, :skipped, :retry (item stays queued),
  #   :setup_error (bot/channel problem, item stays queued) or :not_claimed
  class Poster
    def self.call(...)
      new(...).call
    end

    def initialize(item, client: TelegramClient.new, now: Time.current)
      @item = item
      @client = client
      @now = now
    end

    def call
      return :not_claimed unless item.claim!

      if (reason = skip_reason)
        item.update!(status: "skipped", skip_reason: reason)
        return :skipped
      end

      text = item.message
      message_id = client.send_message(text, link_url: URL.article(item.article, user_signed_in: false))
      item.update!(status: "posted", posted_at: now, sent_message: text, telegram_message_id: message_id,
                   last_error: nil)
      Settings::SocialAutopost.last_error = nil if Settings::SocialAutopost.last_error.present?
      SocialAutopost.push_back_next_post!(now)
      :posted
    rescue TelegramClient::Error => e
      handle_error(e)
    rescue StandardError
      item.update_columns(status: "queued", updated_at: Time.current) if item.reload.sending?
      raise
    end

    private

    attr_reader :item, :client, :now

    def skip_reason
      article = item.article
      return "unpublished" unless article&.published && article.published_at.present? && article.published_at <= now
      return "author_banned" if SocialAutopost.unpostable_author?(article.user)
      return "flagged" if article.score.to_i.negative?
      return unless item.source == "auto" && item.post_after.nil?

      "too_old" if article.published_at < now - [Settings::SocialAutopost.max_age_days.to_i, 1].max.days
    end

    def handle_error(error)
      Settings::SocialAutopost.last_error = error.message
      Settings::SocialAutopost.last_error_at = now.iso8601

      if error.setup_problem?
        if error.retry_after.to_i.positive?
          Settings::SocialAutopost.next_post_not_before = (now + error.retry_after.to_i.seconds).iso8601
        end
        item.update!(status: "queued", last_error: error.message)
        return :setup_error
      end

      attempts = item.attempts + 1
      item.update!(attempts: attempts, last_error: error.message,
                   status: attempts >= SocialAutopostItem::MAX_ATTEMPTS ? "failed" : "queued")
      :retry
    end
  end
end
