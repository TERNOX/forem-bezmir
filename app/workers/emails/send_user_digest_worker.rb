module Emails
  class SendUserDigestWorker
    include Sidekiq::Job

    sidekiq_options queue: :low_priority, retry: 15, lock: :until_executing

    def perform(user_id, options = {})
      options = options.with_indifferent_access
      attempt = ::EmailDigestTestAttempt.find_by(id: options[:test_attempt_id]) if options[:test_attempt_id]

      user = User.find_by(id: user_id)
      unless user&.notification_setting&.email_digest_periodic? && user&.registered?
        attempt&.mark_skipped!(I18n.t("admin.settings.email_digests_controller.skipped_unsubscribed"))
        return
      end

      articles = EmailDigestArticleCollector.new(user).articles_to_send
      unless articles.any?
        attempt&.mark_skipped!(I18n.t("admin.settings.email_digests_controller.skipped_no_articles"))
        return
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

        event_params = { user_id: user.id, context_type: "email", category: "impression" }
        BillboardEvent.create(event_params.merge(billboard_id: first_billboard.id)) if first_billboard.present?
        BillboardEvent.create(event_params.merge(billboard_id: second_billboard.id)) if second_billboard.present?

        attempt&.mark_sent!
      rescue StandardError => e
        Honeybadger.context({ user_id: user.id, article_ids: articles.map(&:id), digest_test_attempt_id: attempt&.id })
        notice_id = Honeybadger.notify(e)
        attempt&.mark_failed!(e, notice_id)
      end
    end
  end
end
