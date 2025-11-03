# frozen_string_literal: true

module Articles
  class TopArticlesDigestWorker
    include Sidekiq::Job

    sidekiq_options queue: :medium_priority, retry: 10

    def perform(run_time = nil)
      reference_time = parse_reference_time(run_time)
      scheduled_run_at = fetch_or_initialize_next_run_at(reference_time)

      attempted = false
      return unless due_for_publication?(reference_time, scheduled_run_at)

      attempted = true

      publisher = Articles::TopArticles::DigestPublisher.new(reference_time: reference_time)
      errors = publisher.publication_errors

      if errors.present?
        record_failure(reference_time, errors)
        return
      end

      unless publisher.send(:publication_due?)
        record_skip(reference_time)
        return
      end

      article = publisher.call

      if article&.persisted?
        record_success(reference_time)
      else
        record_failure(reference_time, [I18n.t("workers.articles.top_articles_digest.publication_failed")])
      end
    rescue StandardError => e
      record_failure(reference_time || Time.zone.now, [e.message])
      raise
    ensure
      update_next_run_at(reference_time) if attempted
    end

    private

    def parse_reference_time(run_time)
      case run_time
      when nil
        Time.zone.now
      when Time
        run_time.in_time_zone
      else
        Time.zone.parse(run_time.to_s)
      end
    rescue ArgumentError
      Time.zone.now
    end

    def fetch_or_initialize_next_run_at(reference_time)
      stored = Settings::General.top_articles_digest_next_run_at
      return stored.in_time_zone if stored.present?

      next_run_at = compute_next_run_at(reference_time)
      Settings::General.set_top_articles_digest_next_run_at(next_run_at)
      next_run_at
    end

    def compute_next_run_at(reference_time)
      schedule_reference = reference_time - 1.minute
      Articles::TopArticles::DigestSchedule
        .new(reference_time: schedule_reference)
        .next_run_at
    end

    def due_for_publication?(reference_time, scheduled_run_at)
      return false if scheduled_run_at.blank?

      reference_utc = reference_time.utc
      scheduled_utc = scheduled_run_at.utc

      reference_utc >= scheduled_utc && reference_utc < scheduled_utc + 1.hour
    end

    def record_success(reference_time)
      Settings::General.set_top_articles_digest_last_run_at(reference_time)
      Settings::General.set_top_articles_digest_last_run_status("success")
      Settings::General.set_top_articles_digest_last_run_message(nil)
    end

    def record_failure(reference_time, errors)
      Settings::General.set_top_articles_digest_last_run_at(reference_time)
      Settings::General.set_top_articles_digest_last_run_status("failed")
      message = Array(errors).compact_blank.join("\n").presence
      Settings::General.set_top_articles_digest_last_run_message(message)
    end

    def record_skip(reference_time)
      Settings::General.set_top_articles_digest_last_run_at(reference_time)
      Settings::General.set_top_articles_digest_last_run_status("skipped")
      Settings::General.set_top_articles_digest_last_run_message(nil)
    end

    def update_next_run_at(reference_time)
      schedule = Articles::TopArticles::DigestSchedule.new(reference_time: reference_time)
      Settings::General.set_top_articles_digest_next_run_at(schedule.next_run_at)
    end
  end
end
