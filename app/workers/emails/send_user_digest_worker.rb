module Emails
  class SendUserDigestWorker
    include Sidekiq::Job
    include Sidekiq::Throttled::Job

    sidekiq_options queue: :low_priority, retry: 15, lock: :until_executing
    sidekiq_throttle(
      concurrency: { limit: 1 },
      threshold: { limit: 1, period: [ENV.fetch("EMAIL_DIGEST_INTERVAL_SECONDS", 60).to_i, 1].max },
      # Preserve the JID that owns the until_executing uniqueness lock.
      requeue: { with: :enqueue },
    )

    SMTP_COOLDOWN_KEY = "email_digest/smtp_retry_at".freeze

    def self.smtp_rate_limited?(error)
      error.is_a?(Net::SMTPUnknownError) &&
        error.message.include?("too many messages from sender in last 60 minutes")
    end

    sidekiq_retry_in do |_count, error|
      1.hour.to_i + rand(5.minutes.to_i) if smtp_rate_limited?(error)
    end

    def perform(user_id, options = {})
      options = options.with_indifferent_access
      attempt = ::EmailDigestTestAttempt.find_by(id: options[:test_attempt_id]) if options[:test_attempt_id]

      attempt&.log_event(:info, I18n.t("admin.settings.email_digests_controller.logs.worker_started"), user_id: user_id)

      user = User.find_by(id: user_id)
      unless user&.notification_setting&.email_digest_periodic? && user&.registered?
        reason = I18n.t("admin.settings.email_digests_controller.skipped_unsubscribed")
        attempt&.log_event(:warn, reason)
        attempt&.mark_skipped!(reason)
        return
      end

      retry_at = Rails.cache.read(SMTP_COOLDOWN_KEY)
      if retry_at && retry_at > Time.current.to_i
        self.class.perform_in(retry_at - Time.current.to_i + rand(60), user_id, options.to_h)
        return
      end

      collector = EmailDigestArticleCollector.new(user)
      attempt&.log_event(:info, I18n.t("admin.settings.email_digests_controller.logs.collecting"))
      articles = collector.articles_to_send

      if articles.blank?
        return unless attempt

        attempt.log_event(:warn, I18n.t("admin.settings.email_digests_controller.logs.no_primary_articles"))
        articles = collector.fallback_articles

        if articles.blank?
          reason = I18n.t("admin.settings.email_digests_controller.skipped_no_articles")
          note = I18n.t("admin.settings.email_digests_controller.notes.no_articles_even_fallback")
          attempt.log_event(:error, note)
          attempt.mark_skipped!(reason, note: note)
          return
        end

        note = I18n.t(
          "admin.settings.email_digests_controller.notes.used_fallback",
          count: articles.count,
        )
        attempt.log_event(
          :info,
          I18n.t(
            "admin.settings.email_digests_controller.logs.used_fallback",
            count: articles.count,
          ),
          article_ids: articles.map(&:id),
        )
        attempt.append_note!(note)
      else
        attempt&.log_event(
          :info,
          I18n.t(
            "admin.settings.email_digests_controller.logs.primary_articles",
            count: articles.count,
          ),
          article_ids: articles.map(&:id),
        )
      end

      tags = user.cached_followed_tag_names&.first(12)
      first_billboard = Billboard.for_display(area: "digest_first",
                                              user_id: user.id,
                                              user_tags: tags,
                                              user_signed_in: true)
      paired_billboard = Billboard.where(published: true,
                                         approved: true,
                                         placement_area: "digest_second",
                                         prefer_paired_with_billboard_id: first_billboard&.id).last

      second_billboard = paired_billboard || Billboard.for_display(area: "digest_second",
                                                                   user_id: user.id,
                                                                   user_tags: tags,
                                                                   user_signed_in: true)

      begin
        DigestMailer.with(user: user, articles: articles.to_a, billboards: [first_billboard, second_billboard])
          .digest_email.deliver_now

        # Track billboard impressions with relaxed durability — these are
        # low-priority analytics writes that don't need synchronous WAL flush.
        if first_billboard.present? || second_billboard.present?
          event_params = { user_id: user.id, context_type: "email", category: "impression" }
          ApplicationRecord.with_synchronous_commit_off do
            BillboardEvent.create(event_params.merge(billboard_id: first_billboard.id)) if first_billboard.present?
            BillboardEvent.create(event_params.merge(billboard_id: second_billboard.id)) if second_billboard.present?
          end
        end

        attempt&.log_event(:info, I18n.t("admin.settings.email_digests_controller.logs.delivery_succeeded"))
        attempt&.mark_sent!(attempt&.status_note)
      rescue StandardError => e
        Honeybadger.context({ user_id: user.id, article_ids: articles.map(&:id), digest_test_attempt_id: attempt&.id })
        if self.class.smtp_rate_limited?(e)
          Rails.cache.write(SMTP_COOLDOWN_KEY, 1.hour.from_now.to_i, expires_in: 1.hour)
          attempt&.log_event(:error, I18n.t("admin.settings.email_digests_controller.logs.delivery_failed"),
                             error: e.message)
          attempt&.mark_failed!(e)
          # Let Sidekiq retain the failed delivery and retry after the provider's window.
          raise
        end

        notice_id = Honeybadger.notify(e)
        attempt&.log_event(:error, I18n.t("admin.settings.email_digests_controller.logs.delivery_failed"),
                           error: e.message, honeybadger_id: notice_id)
        attempt&.mark_failed!(e, notice_id)
      end
    end
  end
end
