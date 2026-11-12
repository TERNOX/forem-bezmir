module SocialAutopost
  # Puts articles into the autoposting queue.
  class Enqueuer
    class Error < StandardError; end

    # Queues every article that currently qualifies and drops automatic items
    # that aged out while waiting.
    # @return [Integer] how many articles were added
    def self.enqueue_candidates(now: Time.current)
      expire_old_items(now)

      CandidateQuery.call(now: now).count do |article|
        SocialAutopostItem.create!(article: article, source: "auto", kind: SocialAutopost.kind_for(article))
        true
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
        false
      end
    end

    def self.expire_old_items(now)
      cutoff = now - [Settings::SocialAutopost.max_age_days.to_i, 1].max.days
      SocialAutopostItem.queued.where(source: "auto", post_after: nil)
        .where(article_id: Article.where(published_at: ...cutoff).select(:id))
        .update_all(status: "skipped", skip_reason: "too_old", updated_at: Time.current)
    end

    # An admin adds an article by hand: it skips the rating rules and goes to
    # the top of the queue.
    def self.add_manual(article)
      raise Error, "Only published articles can be queued." unless article.published

      item = SocialAutopostItem.find_or_initialize_by(article: article)
      update_unless_in_flight(item) do
        if item.posted?
          raise Error, "This article was already posted on #{I18n.l(item.posted_at, format: :short)}."
        end
        raise Error, "This article is being sent right now." if item.sending?

        item.update!(source: "manual", kind: SocialAutopost.kind_for(article), status: "queued",
                     priority: top_priority, attempts: 0, skip_reason: nil, last_error: nil)
      end
      item
    end

    # Called when the bot publishes the weekly "posts of the week" digest.
    def self.enqueue_digest(article, now: Time.current)
      return unless SocialAutopost.active? && Settings::SocialAutopost.post_digest

      item = SocialAutopostItem.find_or_initialize_by(article: article)
      immediately = Settings::SocialAutopost.digest_timing == "immediately"
      queued = update_unless_in_flight(item) do
        next false if item.posted? || item.sending?

        item.update!(source: "digest", kind: "digest", status: "queued", attempts: 0,
                     priority: top_priority, post_after: immediately ? now : nil,
                     skip_reason: nil, last_error: nil)
      end
      SocialAutopost::PostItemWorker.perform_async(item.id) if queued && immediately
      item
    end

    # Status changes on an existing row happen under a row lock, so they can't
    # overwrite a claim (queued -> sending) made by a worker in the meantime.
    def self.update_unless_in_flight(item, &block)
      item.new_record? ? yield : item.with_lock(&block)
    end

    def self.top_priority
      SocialAutopostItem.queued.maximum(:priority).to_i + 1
    end
  end
end
